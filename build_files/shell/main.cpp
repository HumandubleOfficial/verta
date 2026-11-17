/*
    Verta Shell: the taskbar, Start menu and the rest of Verta's desktop UI.

    This is only the launcher: it loads the shell's QML from
    /usr/share/verta-shell/qml and gives it the few things QML can't do on its
    own (start programs, ask KWin to blur behind a window). Everything you see
    is in the QML.

    It has to be a real program (not a script run by Python or qml): KWin lets
    a client manage other windows, which the taskbar needs, only if the
    client's executable has a .desktop file that lists those protocols
    (org.verta.Shell.desktop).

    Built during the image build by build_files/26-shell.sh.

    SPDX-FileCopyrightText: 2026 Verta
    SPDX-License-Identifier: GPL-2.0-or-later
*/
#include <QAbstractListModel>
#include <QBuffer>
#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusConnectionInterface>
#include <QDBusContext>
#include <QDBusMessage>
#include <QDBusMetaType>
#include <QDBusObjectPath>
#include <QDBusServiceWatcher>
#include <QDBusVariant>
#include <QDateTime>
#include <QFile>
#include <QGuiApplication>
#include <QImage>
#include <QJSValue>
#include <QJsonDocument>
#include <QtEndian>
#include <QPainterPath>
#include <QProcess>
#include <QQmlApplicationEngine>
#include <QQmlContext>
#include <QQuickWindow>
#include <QRegion>
#include <QWindow>

#include <KWindowEffects>

class ShellHelper : public QObject
{
    Q_OBJECT
    // On the session bus as org.verta.Shell /Shell: KWin calls toggleStart
    // when the Windows key is tapped on its own (kwinrc ModifierOnlyShortcuts).
    Q_CLASSINFO("D-Bus Interface", "org.verta.Shell")
public:
    using QObject::QObject;

Q_SIGNALS:
    void startRequested();
    void flyoutRequested(const QString &name);

public Q_SLOTS:
    Q_SCRIPTABLE void toggleStart()
    {
        Q_EMIT startRequested();
    }
    // Windows key + A and + N (KDE global shortcuts) land here too.
    Q_SCRIPTABLE void toggleQuickSettings()
    {
        Q_EMIT flyoutRequested(QStringLiteral("quickSettings"));
    }
    Q_SCRIPTABLE void toggleCalendar()
    {
        Q_EMIT flyoutRequested(QStringLiteral("calendar"));
    }

public:
    // Starts a program and forgets about it.
    Q_INVOKABLE bool run(const QString &program, const QStringList &arguments = {})
    {
        return QProcess::startDetached(program, arguments);
    }

    // Runs a shell command and calls back with (output, exit code) when done:
    // Quick Settings reads and changes Wi-Fi, volume and the like this way.
    Q_INVOKABLE void sh(const QString &command, const QJSValue &callback = QJSValue())
    {
        auto *process = new QProcess(this);
        connect(process, &QProcess::finished, this, [process, callback](int exitCode) {
            if (callback.isCallable()) {
                QJSValue cb = callback;
                cb.call({QString::fromUtf8(process->readAllStandardOutput()).trimmed(), exitCode});
            }
            process->deleteLater();
        });
        connect(process, &QProcess::errorOccurred, this, [process, callback](QProcess::ProcessError error) {
            if (error != QProcess::FailedToStart) {
                return;
            }
            if (callback.isCallable()) {
                QJSValue cb = callback;
                cb.call({QString(), -1});
            }
            process->deleteLater();
        });
        process->start(QStringLiteral("/bin/sh"), {QStringLiteral("-c"), command});
    }

    // Blur (and the background contrast KWin adds to it) behind a rounded
    // rectangle of a window, in the window's own coordinates.
    Q_INVOKABLE void setBlur(QWindow *window, qreal x, qreal y, qreal width, qreal height, qreal radius)
    {
        if (!window) {
            return;
        }
        QPainterPath path;
        path.addRoundedRect(QRectF(x, y, width, height), radius, radius);
        const QRegion region(path.toFillPolygon().toPolygon());
        KWindowEffects::enableBlurBehind(window, true, region);
        KWindowEffects::enableBackgroundContrast(window, true, 1.0, 1.0, 1.4, region);
    }

    Q_INVOKABLE void clearBlur(QWindow *window)
    {
        if (window) {
            KWindowEffects::enableBlurBehind(window, false);
            KWindowEffects::enableBackgroundContrast(window, false);
        }
    }
};

// ---- System tray ------------------------------------------------------------
//
// A StatusNotifierItem host: the icons apps like Steam and Discord put in the
// tray, their tooltips, and their menus (com.canonical.dbusmenu), as a model
// for the taskbar. The list of items comes from KDE's watcher (a kded module
// that runs in every Plasma session).

static const QString WATCHER = QStringLiteral("org.kde.StatusNotifierWatcher");
static const QString WATCHER_PATH = QStringLiteral("/StatusNotifierWatcher");
static const QString ITEM = QStringLiteral("org.kde.StatusNotifierItem");
static const QString PROPERTIES = QStringLiteral("org.freedesktop.DBus.Properties");
static const QString DBUSMENU = QStringLiteral("com.canonical.dbusmenu");

// The biggest image of an a(iiay) icon (ARGB32, network byte order), as a
// data: URL QML can show.
static QString pixmapUrl(const QDBusArgument &arg)
{
    QImage best;
    arg.beginArray();
    while (!arg.atEnd()) {
        int w = 0, h = 0;
        QByteArray bytes;
        arg.beginStructure();
        arg >> w >> h >> bytes;
        arg.endStructure();
        if (w <= 0 || h <= 0 || bytes.size() < w * h * 4 || w <= best.width()) {
            continue;
        }
        QImage image(w, h, QImage::Format_ARGB32);
        const uchar *src = reinterpret_cast<const uchar *>(bytes.constData());
        for (int y = 0; y < h; ++y) {
            auto *line = reinterpret_cast<QRgb *>(image.scanLine(y));
            for (int x = 0; x < w; ++x) {
                line[x] = qFromBigEndian<quint32>(src + (y * w + x) * 4);
            }
        }
        best = image;
    }
    arg.endArray();
    if (best.isNull()) {
        return {};
    }
    QByteArray png;
    QBuffer buffer(&png);
    buffer.open(QIODevice::WriteOnly);
    best.save(&buffer, "PNG");
    return QStringLiteral("data:image/png;base64,") + QString::fromLatin1(png.toBase64());
}

// One dbusmenu node (ia{sv}av) and its children, as plain QML values.
static QVariantMap menuNode(const QDBusArgument &arg)
{
    int id = 0;
    QVariantMap props;
    QVariantList children;
    arg.beginStructure();
    arg >> id >> props;
    arg.beginArray();
    while (!arg.atEnd()) {
        QDBusVariant child;
        arg >> child;
        const QVariantMap node = menuNode(child.variant().value<QDBusArgument>());
        if (node.value(QStringLiteral("visible")).toBool()) {
            children << node;
        }
    }
    arg.endArray();
    arg.endStructure();

    // "_" marks a keyboard shortcut letter; "__" is a real underscore.
    QString label = props.value(QStringLiteral("label")).toString();
    label.replace(QStringLiteral("__"), QStringLiteral("\x01")).remove(QLatin1Char('_')).replace(QLatin1Char('\x01'), QLatin1Char('_'));
    return {
        {QStringLiteral("id"), id},
        {QStringLiteral("label"), label},
        {QStringLiteral("enabled"), props.value(QStringLiteral("enabled"), true).toBool()},
        {QStringLiteral("visible"), props.value(QStringLiteral("visible"), true).toBool()},
        {QStringLiteral("separator"), props.value(QStringLiteral("type")).toString() == QLatin1String("separator")},
        {QStringLiteral("checkable"), !props.value(QStringLiteral("toggle-type")).toString().isEmpty()},
        {QStringLiteral("checked"), props.value(QStringLiteral("toggle-state")).toInt() == 1},
        {QStringLiteral("children"), children},
    };
}

class TrayModel : public QAbstractListModel, protected QDBusContext
{
    Q_OBJECT
    // For troubleshooting: qdbus-qt6 org.verta.Shell /Tray menuJson 0
    Q_CLASSINFO("D-Bus Interface", "org.verta.Shell.Tray")
public Q_SLOTS:
    Q_SCRIPTABLE QString menuJson(int row)
    {
        return QString::fromUtf8(QJsonDocument::fromVariant(menu(row)).toJson(QJsonDocument::Compact));
    }
    Q_SCRIPTABLE int count()
    {
        return rowCount();
    }

public:
    enum Roles { IdRole = Qt::UserRole + 1, TitleRole, StatusRole, IconRole, ToolTipRole, HasMenuRole, ItemIsMenuRole };

    struct Item {
        QString key, service, owner, path;
        QString id, title, status, icon, toolTip, menuPath;
        bool itemIsMenu = false;
    };

    explicit TrayModel(QObject *parent = nullptr)
        : QAbstractListModel(parent)
    {
        QDBusConnection bus = QDBusConnection::sessionBus();
        m_host = QStringLiteral("org.kde.StatusNotifierHost-%1").arg(QCoreApplication::applicationPid());
        bus.registerService(m_host);
        auto *watcher = new QDBusServiceWatcher(WATCHER, bus, QDBusServiceWatcher::WatchForRegistration, this);
        connect(watcher, &QDBusServiceWatcher::serviceRegistered, this, &TrayModel::connectToWatcher);
        bus.connect(WATCHER, WATCHER_PATH, WATCHER, QStringLiteral("StatusNotifierItemRegistered"), this, SLOT(itemRegistered(QString)));
        bus.connect(WATCHER, WATCHER_PATH, WATCHER, QStringLiteral("StatusNotifierItemUnregistered"), this, SLOT(itemUnregistered(QString)));
        connectToWatcher();
    }

    int rowCount(const QModelIndex &parent = {}) const override
    {
        return parent.isValid() ? 0 : int(m_items.size());
    }

    QVariant data(const QModelIndex &index, int role) const override
    {
        if (!index.isValid() || index.row() >= m_items.size()) {
            return {};
        }
        const Item &item = m_items.at(index.row());
        switch (role) {
        case IdRole: return item.id;
        case TitleRole: return item.title;
        case StatusRole: return item.status;
        case IconRole: return item.icon;
        case ToolTipRole: return item.toolTip.isEmpty() ? item.title : item.toolTip;
        case HasMenuRole: return !item.menuPath.isEmpty() && item.menuPath != QLatin1String("/NO_DBUSMENU");
        case ItemIsMenuRole: return item.itemIsMenu;
        }
        return {};
    }

    QHash<int, QByteArray> roleNames() const override
    {
        return {{IdRole, "itemId"}, {TitleRole, "title"}, {StatusRole, "status"}, {IconRole, "icon"},
                {ToolTipRole, "toolTip"}, {HasMenuRole, "hasMenu"}, {ItemIsMenuRole, "itemIsMenu"}};
    }

    // Left click, middle click, right click (the app draws its own menu),
    // and the mouse wheel.
    Q_INVOKABLE void activate(int row, int x, int y) { callItem(row, QStringLiteral("Activate"), {x, y}); }
    Q_INVOKABLE void secondaryActivate(int row, int x, int y) { callItem(row, QStringLiteral("SecondaryActivate"), {x, y}); }
    Q_INVOKABLE void contextMenu(int row, int x, int y) { callItem(row, QStringLiteral("ContextMenu"), {x, y}); }
    Q_INVOKABLE void scroll(int row, int delta) { callItem(row, QStringLiteral("Scroll"), {delta, QStringLiteral("vertical")}); }

    // The item's menu as a tree of {id, label, enabled, separator, checkable,
    // checked, children}.
    Q_INVOKABLE QVariantList menu(int row)
    {
        if (row < 0 || row >= m_items.size() || !data(index(row), HasMenuRole).toBool()) {
            return {};
        }
        const Item &item = m_items.at(row);
        QDBusConnection bus = QDBusConnection::sessionBus();
        QDBusMessage about = QDBusMessage::createMethodCall(item.service, item.menuPath, DBUSMENU, QStringLiteral("AboutToShow"));
        about << 0;
        bus.call(about, QDBus::Block, 300);
        QDBusMessage get = QDBusMessage::createMethodCall(item.service, item.menuPath, DBUSMENU, QStringLiteral("GetLayout"));
        get << 0 << -1 << QStringList();
        const QDBusMessage reply = bus.call(get, QDBus::Block, 1000);
        if (reply.type() != QDBusMessage::ReplyMessage || reply.arguments().size() < 2) {
            return {};
        }
        return menuNode(reply.arguments().at(1).value<QDBusArgument>()).value(QStringLiteral("children")).toList();
    }

    Q_INVOKABLE void menuClicked(int row, int id)
    {
        if (row < 0 || row >= m_items.size()) {
            return;
        }
        const Item &item = m_items.at(row);
        QDBusMessage event = QDBusMessage::createMethodCall(item.service, item.menuPath, DBUSMENU, QStringLiteral("Event"));
        event << id << QStringLiteral("clicked") << QVariant::fromValue(QDBusVariant(0))
              << uint(QDateTime::currentSecsSinceEpoch());
        QDBusConnection::sessionBus().asyncCall(event);
    }

private Q_SLOTS:
    void connectToWatcher()
    {
        QDBusConnection bus = QDBusConnection::sessionBus();
        QDBusMessage reg = QDBusMessage::createMethodCall(WATCHER, WATCHER_PATH, WATCHER, QStringLiteral("RegisterStatusNotifierHost"));
        reg << m_host;
        bus.call(reg, QDBus::Block, 2000);
        QDBusMessage get = QDBusMessage::createMethodCall(WATCHER, WATCHER_PATH, PROPERTIES, QStringLiteral("Get"));
        get << WATCHER << QStringLiteral("RegisteredStatusNotifierItems");
        const QDBusMessage reply = bus.call(get, QDBus::Block, 2000);
        if (reply.type() == QDBusMessage::ReplyMessage && !reply.arguments().isEmpty()) {
            const QStringList keys = reply.arguments().at(0).value<QDBusVariant>().variant().toStringList();
            for (const QString &key : keys) {
                itemRegistered(key);
            }
        }
    }

    void itemRegistered(const QString &key)
    {
        for (const Item &item : std::as_const(m_items)) {
            if (item.key == key) {
                return;
            }
        }
        Item item;
        item.key = key;
        const int slash = key.indexOf(QLatin1Char('/'));
        item.service = slash < 0 ? key : key.left(slash);
        item.path = slash < 0 ? QStringLiteral("/StatusNotifierItem") : key.mid(slash);
        QDBusConnection bus = QDBusConnection::sessionBus();
        item.owner = bus.interface()->serviceOwner(item.service).value();
        for (const char *signal : {"NewIcon", "NewTitle", "NewStatus", "NewToolTip", "NewAttentionIcon", "NewMenu"}) {
            bus.connect(item.service, item.path, ITEM, QLatin1String(signal), this, SLOT(itemChanged()));
        }
        beginInsertRows({}, int(m_items.size()), int(m_items.size()));
        m_items.append(item);
        endInsertRows();
        refresh(int(m_items.size()) - 1);
    }

    void itemUnregistered(const QString &key)
    {
        for (int row = 0; row < m_items.size(); ++row) {
            if (m_items.at(row).key == key) {
                beginRemoveRows({}, row, row);
                m_items.removeAt(row);
                endRemoveRows();
                return;
            }
        }
    }

    void itemChanged()
    {
        const QString sender = message().service();
        for (int row = 0; row < m_items.size(); ++row) {
            if (m_items.at(row).owner == sender || m_items.at(row).service == sender) {
                refresh(row);
            }
        }
    }

private:
    void refresh(int row)
    {
        Item &item = m_items[row];
        QDBusMessage getAll = QDBusMessage::createMethodCall(item.service, item.path, PROPERTIES, QStringLiteral("GetAll"));
        getAll << ITEM;
        const QDBusMessage reply = QDBusConnection::sessionBus().call(getAll, QDBus::Block, 1000);
        if (reply.type() != QDBusMessage::ReplyMessage || reply.arguments().isEmpty()) {
            return;
        }
        const QVariantMap props = qdbus_cast<QVariantMap>(reply.arguments().at(0));
        item.id = props.value(QStringLiteral("Id")).toString();
        item.title = props.value(QStringLiteral("Title")).toString();
        item.status = props.value(QStringLiteral("Status")).toString();
        item.itemIsMenu = props.value(QStringLiteral("ItemIsMenu")).toBool();
        item.menuPath = props.value(QStringLiteral("Menu")).value<QDBusObjectPath>().path();

        // Icon: a name from the icon theme (or the app's own icon folder), or
        // pixels; the attention icon while the app asks for attention.
        const bool attention = item.status == QLatin1String("NeedsAttention");
        QString name = props.value(attention ? QStringLiteral("AttentionIconName") : QStringLiteral("IconName")).toString();
        if (name.isEmpty()) {
            name = props.value(QStringLiteral("IconName")).toString();
        }
        const QString themePath = props.value(QStringLiteral("IconThemePath")).toString();
        if (!name.isEmpty() && !themePath.isEmpty()) {
            for (const char *ext : {".png", ".svg"}) {
                const QString file = themePath + QLatin1Char('/') + name + QLatin1String(ext);
                if (QFile::exists(file)) {
                    name = QUrl::fromLocalFile(file).toString();
                    break;
                }
            }
        }
        item.icon = name;
        if (item.icon.isEmpty()) {
            const QVariant pixmap = props.value(attention ? QStringLiteral("AttentionIconPixmap") : QStringLiteral("IconPixmap"));
            if (pixmap.canConvert<QDBusArgument>()) {
                item.icon = pixmapUrl(pixmap.value<QDBusArgument>());
            }
        }

        // Tooltip: (icon name, icon pixels, title, text).
        item.toolTip.clear();
        const QVariant tip = props.value(QStringLiteral("ToolTip"));
        if (tip.canConvert<QDBusArgument>()) {
            const QDBusArgument arg = tip.value<QDBusArgument>();
            QString iconName, title, text;
            arg.beginStructure();
            arg >> iconName;
            pixmapUrl(arg);
            arg >> title >> text;
            arg.endStructure();
            item.toolTip = title;
        }
        Q_EMIT dataChanged(index(row), index(row));
    }

    void callItem(int row, const QString &method, const QVariantList &args)
    {
        if (row < 0 || row >= m_items.size()) {
            return;
        }
        QDBusMessage call = QDBusMessage::createMethodCall(m_items.at(row).service, m_items.at(row).path, ITEM, method);
        call.setArguments(args);
        QDBusConnection::sessionBus().asyncCall(call);
    }

    QString m_host;
    QList<Item> m_items;
};

int main(int argc, char *argv[])
{
    QQuickWindow::setDefaultAlphaBuffer(true);
    QGuiApplication app(argc, argv);
    app.setApplicationName(QStringLiteral("verta-shell"));
    app.setOrganizationName(QStringLiteral("Verta"));
    app.setDesktopFileName(QStringLiteral("org.verta.Shell"));
    // The shell lives as long as the session; closing its last window (the
    // Start menu) must not quit it.
    app.setQuitOnLastWindowClosed(false);

    ShellHelper helper;
    QDBusConnection bus = QDBusConnection::sessionBus();
    if (!bus.registerService(QStringLiteral("org.verta.Shell"))) {
        qWarning("verta-shell: already running");
        return 0;
    }
    bus.registerObject(QStringLiteral("/Shell"), &helper, QDBusConnection::ExportScriptableSlots);

    QQmlApplicationEngine engine;
    // "Host" in QML ("Shell" is the name of the shell's own root type).
    engine.rootContext()->setContextProperty(QStringLiteral("Host"), &helper);
    TrayModel tray;
    bus.registerObject(QStringLiteral("/Tray"), &tray, QDBusConnection::ExportScriptableSlots);
    engine.rootContext()->setContextProperty(QStringLiteral("Tray"), &tray);

    const QString qml = qEnvironmentVariable("VERTA_SHELL_QML", QStringLiteral("/usr/share/verta-shell/qml/Shell.qml"));
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app, [] {
        QCoreApplication::exit(1);
    }, Qt::QueuedConnection);
    engine.load(QUrl::fromLocalFile(qml));

    return app.exec();
}

#include "main.moc"

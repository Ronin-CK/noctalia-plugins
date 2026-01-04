import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Services.UI
import qs.Widgets

Rectangle {
  id: root

  property var pluginApi: null
  property ShellScreen screen
  property string widgetId: ""
  property string section: ""
  
  readonly property bool isVertical: Settings.data.bar.position === "left" || Settings.data.bar.position === "right"

  // Configuration
  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  // Widget settings
  readonly property var watchlist: cfg.watchlist || defaults.watchlist || []
  readonly property int checkInterval: cfg.checkInterval ?? defaults.checkInterval ?? 30
  readonly property var notifiedGames: cfg.notifiedGames || defaults.notifiedGames || []

  // State
  property var gamesOnTarget: []
  property bool loading: false
  property bool hasNotifications: gamesOnTarget.length > 0

  implicitWidth: Math.max(60, isVertical ? (Style.capsuleHeight || 32) : contentWidth)
  implicitHeight: Math.max(32, isVertical ? contentHeight : (Style.capsuleHeight || 32))
  radius: Style.radiusM || 8
  color: Style.capsuleColor || "#1E1E1E"
  border.color: Style.capsuleBorderColor || "#2E2E2E"
  border.width: Style.capsuleBorderWidth || 1

  readonly property real contentWidth: {
    if (isVertical) return Style.capsuleHeight || 32;
    var iconWidth = Style.toOdd ? Style.toOdd(Style.capsuleHeight * 0.6) : 20;
    var textWidth = gamesText ? (gamesText.implicitWidth + (Style.marginS || 4)) : 60;
    return iconWidth + textWidth + (Style.marginM || 8) * 2 + 24;
  }

  readonly property real contentHeight: {
    if (!isVertical) return Style.capsuleHeight || 32;
    var iconHeight = Style.toOdd ? Style.toOdd(Style.capsuleHeight * 0.6) : 20;
    var textHeight = gamesText ? gamesText.implicitHeight : 16;
    return Math.max(iconHeight, textHeight) + (Style.marginS || 4) * 2;
  }

  // Update timer
  Timer {
    id: updateTimer
    interval: checkInterval * 60000
    running: watchlist.length > 0
    repeat: true
    triggeredOnStart: true
    onTriggered: checkPrices()
  }

  Component.onCompleted: {
    console.log("Steam Price Watcher Widget loaded");
    console.log("Watchlist:", JSON.stringify(watchlist));
  }

  function checkPrices() {
    if (loading || watchlist.length === 0) return;
    loading = true;
    
    var games = [];
    for (var i = 0; i < watchlist.length; i++) {
      var game = watchlist[i];
      checkGamePrice(game);
    }
  }

  property int pendingChecks: 0

  function checkGamePrice(game) {
    pendingChecks++;
    
    var process = Qt.createQmlObject(`
      import Quickshell.Io
      Process {
        id: priceProcess
        running: false
        command: ["curl", "-s", "https://store.steampowered.com/api/appdetails?appids=${game.appId}&cc=br"]
        stdout: StdioCollector {}
        property var gameData: null
        
        Component.onCompleted: {
          gameData = ${JSON.stringify(game)};
          running = true;
        }
        
        onExited: (exitCode) => {
          if (exitCode === 0) {
            try {
              var response = JSON.parse(stdout.text);
              var appData = response["${game.appId}"];
              if (appData && appData.success && appData.data) {
                var priceData = appData.data.price_overview;
                if (priceData) {
                  var currentPrice = priceData.final / 100;
                  gameData.currentPrice = currentPrice;
                  gameData.currency = priceData.currency;
                  
                  if (currentPrice <= gameData.targetPrice) {
                    root.addGameOnTarget(gameData);
                  }
                }
              }
            } catch (e) {
              console.error("Error parsing Steam API response:", e);
            }
          }
          
          root.pendingChecks--;
          if (root.pendingChecks === 0) {
            root.loading = false;
          }
          
          priceProcess.destroy();
        }
      }
    `, root, "priceProcess");
  }

  function addGameOnTarget(game) {
    // Check if already in list
    for (var i = 0; i < gamesOnTarget.length; i++) {
      if (gamesOnTarget[i].appId === game.appId) {
        return;
      }
    }
    
    var temp = gamesOnTarget.slice();
    temp.push(game);
    gamesOnTarget = temp;
    
    // Send notification if not already notified
    if (!isGameNotified(game.appId)) {
      sendNotification(game);
      markGameAsNotified(game.appId);
    }
  }

  function isGameNotified(appId) {
    return notifiedGames.indexOf(appId) !== -1;
  }

  function markGameAsNotified(appId) {
    if (pluginApi && pluginApi.pluginSettings) {
      var temp = notifiedGames.slice();
      temp.push(appId);
      pluginApi.pluginSettings.notifiedGames = temp;
      pluginApi.saveSettings();
    }
  }

  function sendNotification(game) {
    var notifyProcess = Qt.createQmlObject(`
      import Quickshell.Io
      Process {
        running: true
        command: [
          "notify-send",
          "-a", "Noctalia Shell",
          "-i", "applications-games",
          "🎮 Steam Price Watcher",
          "${game.name} atingiu R$ ${game.currentPrice.toFixed(2)}!\\nPreço alvo: R$ ${game.targetPrice.toFixed(2)}"
        ]
        onExited: (exitCode) => {
          destroy();
        }
      }
    `, root, "notifyProcess");
  }

  readonly property string displayText: {
    if (loading) return pluginApi?.tr("steam-price-watcher.loading") || "Verificando...";
    if (watchlist.length === 0) return pluginApi?.tr("steam-price-watcher.no-games") || "Sem jogos";
    if (hasNotifications) return `${gamesOnTarget.length} ${gamesOnTarget.length === 1 ? "jogo" : "jogos"}`;
    return `${watchlist.length} ${watchlist.length === 1 ? "jogo" : "jogos"}`;
  }

  readonly property string tooltipText: {
    if (hasNotifications) {
      var text = pluginApi?.tr("steam-price-watcher.tooltip.on-target") || "Jogos no preço-alvo:";
      for (var i = 0; i < gamesOnTarget.length; i++) {
        text += `\n• ${gamesOnTarget[i].name} - R$ ${gamesOnTarget[i].currentPrice.toFixed(2)}`;
      }
      return text + "\n\n" + (pluginApi?.tr("steam-price-watcher.tooltip.click") || "Clique para ver detalhes");
    }
    if (watchlist.length > 0) {
      return (pluginApi?.tr("steam-price-watcher.tooltip.monitoring") || "Monitorando") + ` ${watchlist.length} ${watchlist.length === 1 ? "jogo" : "jogos"}`;
    }
    return pluginApi?.tr("steam-price-watcher.tooltip.no-games") || "Nenhum jogo cadastrado";
  }

  RowLayout {
    anchors.fill: parent
    anchors.leftMargin: isVertical ? 0 : (Style.marginM || 8)
    anchors.rightMargin: isVertical ? 0 : 32
    anchors.topMargin: isVertical ? (Style.marginS || 4) : 0
    anchors.bottomMargin: isVertical ? (Style.marginS || 4) : 0
    spacing: Style.marginS || 4
    visible: !isVertical

    Item {
      Layout.preferredWidth: iconSize
      Layout.preferredHeight: iconSize
      Layout.alignment: Qt.AlignVCenter
      
      readonly property int iconSize: Style.toOdd ? Style.toOdd(Style.capsuleHeight * 0.5) : 16

      NIcon {
        anchors.fill: parent
        icon: loading ? "loader" : "package"
        color: hasNotifications ? (Color.mPrimary || "#2196F3") : (Color.mOnSurface || "#FFFFFF")
        pointSize: parent.iconSize
        
        RotationAnimator on rotation {
          running: loading
          from: 0
          to: 360
          duration: 1000
          loops: Animation.Infinite
        }
      }

      // Notification indicator
      Rectangle {
        visible: hasNotifications && !loading
        width: 8
        height: 8
        radius: 4
        color: Color.mError || "#F44336"
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.rightMargin: -2
        anchors.topMargin: -2
        border.color: root.color
        border.width: 1
      }
    }

    NText {
      id: gamesText
      text: displayText
      color: hasNotifications ? (Color.mPrimary || "#2196F3") : (Color.mOnSurface || "#FFFFFF")
      pointSize: Style.barFontSize || 11
      applyUiScale: false
      Layout.alignment: Qt.AlignVCenter
    }
  }

  // Mouse interaction
  MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton

    onClicked: {
      if (pluginApi) {
        pluginApi.openPanel(screen);
      }
    }

    onEntered: {
      if (tooltipText) {
        TooltipService.show(root, tooltipText, BarService.getTooltipDirection());
      }
    }
    
    onExited: {
      TooltipService.hide();
    }
  }
}

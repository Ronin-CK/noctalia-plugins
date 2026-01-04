import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Widgets

Item {
  id: root

  // Plugin API (injected by PluginPanelSlot)
  property var pluginApi: null
  
  // SmartPanel properties
  readonly property var geometryPlaceholder: panelContainer
  property real contentPreferredWidth: 450 * Style.uiScaleRatio
  property real contentPreferredHeight: 400 * Style.uiScaleRatio
  readonly property bool allowAttach: true
  
  anchors.fill: parent

  // Configuration
  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  // Local state
  property var watchlist: cfg.watchlist || defaults.watchlist || []
  property var gamesWithPrices: []
  property bool loading: false

  Component.onCompleted: {
    refreshPrices();
  }

  function refreshPrices() {
    if (loading || watchlist.length === 0) return;
    loading = true;
    gamesWithPrices = [];
    
    for (var i = 0; i < watchlist.length; i++) {
      fetchGamePrice(watchlist[i]);
    }
  }

  property int pendingFetches: 0

  function fetchGamePrice(game) {
    pendingFetches++;
    
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
                  gameData.currentPrice = priceData.final / 100;
                  gameData.currency = priceData.currency;
                  gameData.discountPercent = priceData.discount_percent || 0;
                  root.addGameWithPrice(gameData);
                } else {
                  gameData.currentPrice = 0;
                  gameData.currency = "BRL";
                  gameData.error = "Preço não disponível";
                  root.addGameWithPrice(gameData);
                }
              }
            } catch (e) {
              console.error("Error parsing Steam API response:", e);
              gameData.error = "Erro ao buscar preço";
              root.addGameWithPrice(gameData);
            }
          }
          
          root.pendingFetches--;
          if (root.pendingFetches === 0) {
            root.loading = false;
          }
          
          priceProcess.destroy();
        }
      }
    `, root, "priceProcess");
  }

  function addGameWithPrice(game) {
    var temp = gamesWithPrices.slice();
    temp.push(game);
    gamesWithPrices = temp;
  }

  function removeGame(appId) {
    var temp = [];
    for (var i = 0; i < watchlist.length; i++) {
      if (watchlist[i].appId !== appId) {
        temp.push(watchlist[i]);
      }
    }
    
    if (pluginApi && pluginApi.pluginSettings) {
      pluginApi.pluginSettings.watchlist = temp;
      pluginApi.saveSettings();
      console.log("Steam Price Watcher: Removed game", appId);
    }
    
    refreshPrices();
  }

  function updateTargetPrice(appId, newPrice) {
    if (pluginApi && pluginApi.pluginSettings) {
      for (var i = 0; i < pluginApi.pluginSettings.watchlist.length; i++) {
        if (pluginApi.pluginSettings.watchlist[i].appId === appId) {
          pluginApi.pluginSettings.watchlist[i].targetPrice = newPrice;
          break;
        }
      }
      pluginApi.saveSettings();
      console.log("Steam Price Watcher: Updated target price for", appId, "to", newPrice);
      
      // Remove from notified games to allow re-notification
      var notified = pluginApi.pluginSettings.notifiedGames || [];
      var newNotified = [];
      for (var j = 0; j < notified.length; j++) {
        if (notified[j] !== appId) {
          newNotified.push(notified[j]);
        }
      }
      pluginApi.pluginSettings.notifiedGames = newNotified;
      pluginApi.saveSettings();
      
      refreshPrices();
    }
  }

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: Color.transparent

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginM

      // Header
      NBox {
        Layout.fillWidth: true
        Layout.preferredHeight: headerContent.implicitHeight + Style.marginM * 2
        color: Color.mSurfaceVariant

        ColumnLayout {
          id: headerContent
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginS

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.marginM

            NIcon {
              icon: "package"
              pointSize: Style.fontSizeXXL
              color: Color.mPrimary
            }

            NText {
              text: "Steam Price Watcher"
              pointSize: Style.fontSizeL
              font.weight: Style.fontWeightBold
              color: Color.mOnSurface
              Layout.fillWidth: true
            }

            NIconButton {
              icon: "refresh"
              tooltipText: pluginApi?.tr("steam-price-watcher.refresh") || "Atualizar preços"
              baseSize: Style.baseWidgetSize * 0.8
              enabled: !loading
              onClicked: refreshPrices()
            }
          }
        }
      }

      // Games list
      NBox {
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: Color.mSurface

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginM

          NText {
            text: loading ? 
              (pluginApi?.tr("steam-price-watcher.loading-prices") || "Carregando preços...") :
              watchlist.length === 0 ?
                (pluginApi?.tr("steam-price-watcher.no-games-message") || "Nenhum jogo cadastrado. Adicione jogos nas configurações.") :
                `${watchlist.length} ${watchlist.length === 1 ? "jogo" : "jogos"} na watchlist`
            color: Color.mOnSurface
            pointSize: Style.fontSizeM
            Layout.fillWidth: true
          }

          ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            ListView {
              id: gamesListView
              model: gamesWithPrices
              spacing: Style.marginS

              delegate: NBox {
                required property var modelData
                required property int index

                width: gamesListView.width
                implicitHeight: gameContent.implicitHeight + Style.marginM * 2
                color: modelData.currentPrice && modelData.currentPrice <= modelData.targetPrice ? 
                  Color.mSuccessContainer : Color.mSurfaceVariant

                ColumnLayout {
                  id: gameContent
                  anchors.fill: parent
                  anchors.margins: Style.marginM
                  spacing: Style.marginS

                  RowLayout {
                    Layout.fillWidth: true
                    spacing: Style.marginM

                    ColumnLayout {
                      Layout.fillWidth: true
                      spacing: Style.marginXS

                      NText {
                        text: modelData.name
                        color: Color.mOnSurface
                        pointSize: Style.fontSizeM
                        font.weight: Style.fontWeightBold
                        Layout.fillWidth: true
                        wrapMode: Text.WordWrap
                      }

                      NText {
                        text: `App ID: ${modelData.appId}`
                        color: Color.mOnSurfaceVariant
                        pointSize: Style.fontSizeS
                      }
                    }

                    NIconButton {
                      icon: "trash"
                      tooltipText: pluginApi?.tr("steam-price-watcher.remove") || "Remover"
                      baseSize: Style.baseWidgetSize * 0.7
                      colorBg: Color.mError
                      colorFg: Color.mOnError
                      onClicked: removeGame(modelData.appId)
                    }
                  }

                  Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: Color.mOutline
                  }

                  GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: Style.marginM
                    rowSpacing: Style.marginS

                    // Current price
                    NText {
                      text: pluginApi?.tr("steam-price-watcher.current-price") || "Preço atual:"
                      color: Color.mOnSurfaceVariant
                      pointSize: Style.fontSizeS
                    }

                    NText {
                      text: modelData.error ? modelData.error : 
                        modelData.currentPrice !== undefined ? 
                          `R$ ${modelData.currentPrice.toFixed(2)}${modelData.discountPercent > 0 ? " (-" + modelData.discountPercent + "%)" : ""}` :
                          (pluginApi?.tr("steam-price-watcher.loading") || "Carregando...")
                      color: modelData.error ? Color.mError : 
                        modelData.currentPrice && modelData.currentPrice <= modelData.targetPrice ? Color.mSuccess : Color.mOnSurface
                      pointSize: Style.fontSizeM
                      font.weight: Style.fontWeightBold
                    }

                    // Target price
                    NText {
                      text: pluginApi?.tr("steam-price-watcher.target-price") || "Preço alvo:"
                      color: Color.mOnSurfaceVariant
                      pointSize: Style.fontSizeS
                    }

                    RowLayout {
                      spacing: Style.marginS

                      NText {
                        text: `R$ ${modelData.targetPrice.toFixed(2)}`
                        color: Color.mPrimary
                        pointSize: Style.fontSizeM
                        font.weight: Style.fontWeightBold
                      }

                      NIconButton {
                        icon: "pencil"
                        tooltipText: pluginApi?.tr("steam-price-watcher.edit-price") || "Editar preço"
                        baseSize: Style.baseWidgetSize * 0.6
                        onClicked: editPriceDialog.open(modelData)
                      }
                    }
                  }

                  // Status indicator
                  Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: statusText.implicitHeight + Style.marginS * 2
                    radius: Style.iRadiusS
                    color: modelData.currentPrice && modelData.currentPrice <= modelData.targetPrice ?
                      Color.mSuccess : Color.transparent
                    border.color: modelData.currentPrice && modelData.currentPrice <= modelData.targetPrice ?
                      Color.mSuccess : Color.mOutline
                    border.width: Style.borderS
                    visible: modelData.currentPrice !== undefined && !modelData.error

                    NText {
                      id: statusText
                      anchors.centerIn: parent
                      text: modelData.currentPrice <= modelData.targetPrice ?
                        "🎯 " + (pluginApi?.tr("steam-price-watcher.target-reached") || "Preço-alvo atingido!") :
                        `💰 ${((1 - modelData.currentPrice / modelData.targetPrice) * 100).toFixed(0)}% ${pluginApi?.tr("steam-price-watcher.above-target") || "acima do alvo"}`
                      color: modelData.currentPrice <= modelData.targetPrice ? Color.mOnSuccess : Color.mOnSurfaceVariant
                      pointSize: Style.fontSizeS
                      font.weight: Style.fontWeightMedium
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  // Edit Price Dialog
  Popup {
    id: editPriceDialog
    anchors.centerIn: parent
    width: 350 * Style.uiScaleRatio
    height: contentItem.implicitHeight + Style.marginL * 2
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    property var gameData: null

    function open(game) {
      gameData = game;
      newPriceInput.text = game.targetPrice.toFixed(2);
      visible = true;
    }

    background: Rectangle {
      color: Color.mSurface
      radius: Style.iRadiusL
      border.color: Color.mOutline
      border.width: Style.borderM
    }

    contentItem: ColumnLayout {
      spacing: Style.marginM

      NText {
        text: pluginApi?.tr("steam-price-watcher.edit-target-price") || "Editar Preço-Alvo"
        color: Color.mOnSurface
        pointSize: Style.fontSizeL
        font.weight: Style.fontWeightBold
      }

      NText {
        text: editPriceDialog.gameData ? editPriceDialog.gameData.name : ""
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeM
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        NText {
          text: "R$"
          color: Color.mOnSurface
          pointSize: Style.fontSizeM
        }

        NTextInput {
          id: newPriceInput
          Layout.fillWidth: true
          Layout.preferredHeight: Style.baseWidgetSize
          text: "0.00"
          
          property var numberValidator: DoubleValidator {
            bottom: 0
            decimals: 2
            notation: DoubleValidator.StandardNotation
          }
          
          Component.onCompleted: {
            if (inputItem) {
              inputItem.validator = numberValidator;
            }
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        Item { Layout.fillWidth: true }

        NButton {
          text: pluginApi?.tr("steam-price-watcher.cancel") || "Cancelar"
          onClicked: editPriceDialog.close()
        }

        NButton {
          text: pluginApi?.tr("steam-price-watcher.save") || "Salvar"
          onClicked: {
            var newPrice = parseFloat(newPriceInput.text);
            if (!isNaN(newPrice) && newPrice > 0) {
              updateTargetPrice(editPriceDialog.gameData.appId, newPrice);
              editPriceDialog.close();
            }
          }
        }
      }
    }
  }
}

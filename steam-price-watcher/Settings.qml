import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Widgets

ColumnLayout {
  id: root
  spacing: Style.marginM

  property var pluginApi: null
  
  // Configuration
  property var cfg: pluginApi?.pluginSettings || ({})
  property var defaults: pluginApi?.manifest?.metadata?.defaultSettings || ({})

  property var watchlist: cfg.watchlist || defaults.watchlist || []
  property int checkInterval: cfg.checkInterval ?? defaults.checkInterval ?? 30

  // Search state
  property var searchResults: []
  property bool searching: false
  property string searchQuery: ""

  // Header
  NText {
    text: "Steam Price Watcher"
    pointSize: Style.fontSizeXXL
    font.weight: Style.fontWeightBold
    color: Color.mOnBackground
  }

  NText {
    text: pluginApi?.tr("steam-price-watcher.settings.description") || 
      "Configure o intervalo de verificação e adicione jogos à sua watchlist pesquisando na Steam."
    color: Color.mOnSurfaceVariant
    pointSize: Style.fontSizeM
    Layout.fillWidth: true
    wrapMode: Text.WordWrap
  }

  // Check interval setting
  NBox {
    Layout.fillWidth: true
    Layout.preferredHeight: intervalContent.implicitHeight + Style.marginM * 2
    color: Color.mSurfaceVariant

    ColumnLayout {
      id: intervalContent
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginS

      NText {
        text: pluginApi?.tr("steam-price-watcher.settings.check-interval") || "Intervalo de Verificação"
        pointSize: Style.fontSizeL
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        NText {
          text: pluginApi?.tr("steam-price-watcher.settings.check-every") || "Verificar preços a cada"
          color: Color.mOnSurface
          pointSize: Style.fontSizeM
        }

        SpinBox {
          id: intervalSpinBox
          from: 15
          to: 1440
          stepSize: 15
          value: checkInterval
          editable: true

          onValueModified: {
            if (pluginApi && pluginApi.pluginSettings) {
              pluginApi.pluginSettings.checkInterval = value;
              pluginApi.saveSettings();
            }
          }

          contentItem: TextInput {
            text: intervalSpinBox.textFromValue(intervalSpinBox.value, intervalSpinBox.locale)
            font: intervalSpinBox.font
            color: Color.mOnSurface
            horizontalAlignment: Qt.AlignHCenter
            verticalAlignment: Qt.AlignVCenter
            readOnly: !intervalSpinBox.editable
            validator: intervalSpinBox.validator
            inputMethodHints: Qt.ImhFormattedNumbersOnly
          }

          up.indicator: Rectangle {
            x: parent.width - width - Style.marginS
            y: Style.marginS
            implicitWidth: Style.baseWidgetSize * 0.5
            implicitHeight: Style.baseWidgetSize * 0.4
            color: intervalSpinBox.up.pressed ? Color.mPrimary : Color.mSurface
            radius: Style.iRadiusS
            border.color: Color.mOutline

            NIcon {
              anchors.centerIn: parent
              icon: "caret-up"
              pointSize: Style.fontSizeS
              color: Color.mOnSurface
            }
          }

          down.indicator: Rectangle {
            x: parent.width - width - Style.marginS
            y: parent.height - height - Style.marginS
            implicitWidth: Style.baseWidgetSize * 0.5
            implicitHeight: Style.baseWidgetSize * 0.4
            color: intervalSpinBox.down.pressed ? Color.mPrimary : Color.mSurface
            radius: Style.iRadiusS
            border.color: Color.mOutline

            NIcon {
              anchors.centerIn: parent
              icon: "caret-down"
              pointSize: Style.fontSizeS
              color: Color.mOnSurface
            }
          }

          background: Rectangle {
            color: Color.mSurface
            border.color: Color.mOutline
            border.width: Style.borderS
            radius: Style.iRadiusM
          }
        }

        NText {
          text: pluginApi?.tr("steam-price-watcher.settings.minutes") || "minutos"
          color: Color.mOnSurface
          pointSize: Style.fontSizeM
        }
      }

      NText {
        text: pluginApi?.tr("steam-price-watcher.settings.interval-warning") || 
          "⚠️ Intervalos muito curtos podem resultar em muitas requisições à API da Steam."
        color: Color.mWarning
        pointSize: Style.fontSizeS
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
        visible: checkInterval < 30
      }
    }
  }

  // Search section
  NBox {
    Layout.fillWidth: true
    Layout.fillHeight: true
    color: Color.mSurfaceVariant

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.marginM
      spacing: Style.marginM

      NText {
        text: pluginApi?.tr("steam-price-watcher.settings.add-games") || "Adicionar Jogos"
        pointSize: Style.fontSizeL
        font.weight: Style.fontWeightBold
        color: Color.mOnSurface
      }

      NText {
        text: pluginApi?.tr("steam-price-watcher.settings.search-hint") || 
          "Pesquise jogos pelo nome ou App ID da Steam. Você pode encontrar o App ID na URL da página do jogo."
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeS
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        NTextInput {
          id: searchInput
          Layout.fillWidth: true
          Layout.preferredHeight: Style.baseWidgetSize
          placeholderText: pluginApi?.tr("steam-price-watcher.settings.search-placeholder") || 
            "Digite o App ID (ex: 730 para CS2)"
          
          onAccepted: {
            if (text.trim().length > 0) {
              searchGame(text.trim());
            }
          }
        }

        NButton {
          text: pluginApi?.tr("steam-price-watcher.settings.search") || "Pesquisar"
          enabled: !searching && searchInput.text.trim().length > 0
          onClicked: {
            if (searchInput.text.trim().length > 0) {
              searchGame(searchInput.text.trim());
            }
          }
        }
      }

      // Loading indicator
      NText {
        visible: searching
        text: pluginApi?.tr("steam-price-watcher.settings.searching") || "Pesquisando..."
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeM
        Layout.fillWidth: true
        
        NIcon {
          id: loadingIcon
          anchors.left: parent.left
          anchors.leftMargin: -25
          anchors.verticalCenter: parent.verticalCenter
          icon: "loader"
          pointSize: Style.fontSizeM
          color: Color.mPrimary
          
          RotationAnimator on rotation {
            running: searching
            from: 0
            to: 360
            duration: 1000
            loops: Animation.Infinite
          }
        }
      }

      // Search results
      ScrollView {
        Layout.fillWidth: true
        Layout.fillHeight: true
        visible: searchResults.length > 0
        clip: true

        ListView {
          model: searchResults
          spacing: Style.marginS

          delegate: NBox {
            required property var modelData
            required property int index

            width: ListView.view.width
            implicitHeight: resultContent.implicitHeight + Style.marginM * 2
            color: Color.mSurface

            ColumnLayout {
              id: resultContent
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

                  NText {
                    text: modelData.price ? `R$ ${modelData.price.toFixed(2)}` : 
                      (pluginApi?.tr("steam-price-watcher.settings.free") || "Gratuito")
                    color: Color.mPrimary
                    pointSize: Style.fontSizeM
                    visible: modelData.price !== undefined
                  }
                }

                NButton {
                  text: isGameInWatchlist(modelData.appId) ? 
                    (pluginApi?.tr("steam-price-watcher.settings.added") || "✓ Adicionado") :
                    (pluginApi?.tr("steam-price-watcher.settings.add") || "+ Adicionar")
                  enabled: !isGameInWatchlist(modelData.appId)
                  onClicked: {
                    if (modelData.price && modelData.price > 0) {
                      addGameDialog.open(modelData);
                    }
                  }
                }
              }

              NText {
                text: pluginApi?.tr("steam-price-watcher.settings.free-game-note") || 
                  "Jogos gratuitos não podem ser adicionados à watchlist."
                color: Color.mOnSurfaceVariant
                pointSize: Style.fontSizeS
                Layout.fillWidth: true
                wrapMode: Text.WordWrap
                visible: !modelData.price || modelData.price === 0
              }
            }
          }
        }
      }

      // No results message
      NText {
        visible: !searching && searchResults.length === 0 && searchQuery.length > 0
        text: pluginApi?.tr("steam-price-watcher.settings.no-results") || 
          "Nenhum jogo encontrado. Verifique o App ID e tente novamente."
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeM
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
      }

      // Current watchlist
      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS
        visible: watchlist.length > 0

        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 1
          color: Color.mOutline
        }

        NText {
          text: pluginApi?.tr("steam-price-watcher.settings.current-watchlist") || 
            `Watchlist atual (${watchlist.length} ${watchlist.length === 1 ? "jogo" : "jogos"})`
          color: Color.mOnSurface
          pointSize: Style.fontSizeM
          font.weight: Style.fontWeightBold
        }

        Repeater {
          model: watchlist.slice(0, 5) // Show only first 5

          NText {
            required property var modelData
            text: `• ${modelData.name} - R$ ${modelData.targetPrice.toFixed(2)}`
            color: Color.mOnSurfaceVariant
            pointSize: Style.fontSizeS
          }
        }

        NText {
          visible: watchlist.length > 5
          text: `... ${pluginApi?.tr("steam-price-watcher.settings.and-more") || "e mais"} ${watchlist.length - 5}`
          color: Color.mOnSurfaceVariant
          pointSize: Style.fontSizeS
          font.italic: true
        }
      }
    }
  }

  // Add Game Dialog
  Popup {
    id: addGameDialog
    anchors.centerIn: Overlay.overlay
    width: 400 * Style.uiScaleRatio
    height: contentItem.implicitHeight + Style.marginL * 2
    modal: true
    closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

    property var gameData: null

    function open(game) {
      gameData = game;
      targetPriceInput.text = game.price ? (game.price * 0.8).toFixed(2) : "0.00";
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
        text: pluginApi?.tr("steam-price-watcher.settings.add-to-watchlist") || "Adicionar à Watchlist"
        color: Color.mOnSurface
        pointSize: Style.fontSizeL
        font.weight: Style.fontWeightBold
      }

      NText {
        text: addGameDialog.gameData ? addGameDialog.gameData.name : ""
        color: Color.mOnSurfaceVariant
        pointSize: Style.fontSizeM
        Layout.fillWidth: true
        wrapMode: Text.WordWrap
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NText {
          text: pluginApi?.tr("steam-price-watcher.settings.current-price-label") || "Preço atual:"
          color: Color.mOnSurfaceVariant
          pointSize: Style.fontSizeS
        }

        NText {
          text: addGameDialog.gameData && addGameDialog.gameData.price ? 
            `R$ ${addGameDialog.gameData.price.toFixed(2)}` : ""
          color: Color.mOnSurface
          pointSize: Style.fontSizeM
          font.weight: Style.fontWeightBold
        }
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.marginS

        NText {
          text: pluginApi?.tr("steam-price-watcher.settings.target-price-label") || "Preço-alvo (R$):"
          color: Color.mOnSurface
          pointSize: Style.fontSizeM
        }

        NTextInput {
          id: targetPriceInput
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

        NText {
          text: pluginApi?.tr("steam-price-watcher.settings.target-price-hint") || 
            "💡 Sugerimos 20% abaixo do preço atual para boas ofertas."
          color: Color.mOnSurfaceVariant
          pointSize: Style.fontSizeXS
          Layout.fillWidth: true
          wrapMode: Text.WordWrap
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.marginM

        Item { Layout.fillWidth: true }

        NButton {
          text: pluginApi?.tr("steam-price-watcher.cancel") || "Cancelar"
          onClicked: addGameDialog.close()
        }

        NButton {
          text: pluginApi?.tr("steam-price-watcher.add") || "Adicionar"
          onClicked: {
            var targetPrice = parseFloat(targetPriceInput.text);
            if (!isNaN(targetPrice) && targetPrice > 0) {
              addGameToWatchlist(addGameDialog.gameData, targetPrice);
              addGameDialog.close();
            }
          }
        }
      }
    }
  }

  // Functions
  function searchGame(query) {
    searching = true;
    searchQuery = query;
    searchResults = [];
    
    // Check if it's an App ID (numeric)
    var appId = parseInt(query);
    if (!isNaN(appId)) {
      fetchGameDetails(appId);
    } else {
      searching = false;
      searchResults = [];
    }
  }

  function fetchGameDetails(appId) {
    var process = Qt.createQmlObject(`
      import Quickshell.Io
      Process {
        running: true
        command: ["curl", "-s", "https://store.steampowered.com/api/appdetails?appids=${appId}&cc=br"]
        stdout: StdioCollector {}
        
        onExited: (exitCode) => {
          if (exitCode === 0) {
            try {
              var response = JSON.parse(stdout.text);
              var appData = response["${appId}"];
              if (appData && appData.success && appData.data) {
                var game = {
                  appId: ${appId},
                  name: appData.data.name,
                  price: 0
                };
                
                if (appData.data.price_overview) {
                  game.price = appData.data.price_overview.final / 100;
                }
                
                var temp = [];
                temp.push(game);
                root.searchResults = temp;
              } else {
                root.searchResults = [];
              }
            } catch (e) {
              console.error("Error parsing Steam API response:", e);
              root.searchResults = [];
            }
          }
          
          root.searching = false;
          destroy();
        }
      }
    `, root, "searchProcess");
  }

  function isGameInWatchlist(appId) {
    for (var i = 0; i < watchlist.length; i++) {
      if (watchlist[i].appId === appId) {
        return true;
      }
    }
    return false;
  }

  function addGameToWatchlist(game, targetPrice) {
    if (pluginApi && pluginApi.pluginSettings) {
      var temp = watchlist.slice();
      temp.push({
        appId: game.appId,
        name: game.name,
        targetPrice: targetPrice
      });
      
      pluginApi.pluginSettings.watchlist = temp;
      pluginApi.saveSettings();
      console.log("Steam Price Watcher: Added", game.name, "with target price", targetPrice);
      
      // Clear search
      searchInput.text = "";
      searchResults = [];
      searchQuery = "";
    }
  }
}

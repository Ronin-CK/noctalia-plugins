import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.Commons
import qs.Services.UI
import qs.Widgets

Item {
  id: root

  property var pluginApi: null
  readonly property var geometryPlaceholder: panelContainer
  property real contentPreferredWidth: 700 * Style.uiScaleRatio
  property real contentPreferredHeight: 500 * Style.uiScaleRatio
  readonly property bool allowAttach: true
  anchors.fill: parent
  property ListModel todosModel: ListModel {}
  property ListModel filteredTodosModel: ListModel {}
  property bool showCompleted: false
  property var rawTodos: []

  Binding {
    target: root
    property: "rawTodos"
    value: pluginApi?.pluginSettings?.todos || []
  }

  Component.onCompleted: {
    if (pluginApi) {
      Logger.i("Todo", "Panel initialized");
      root.showCompleted = pluginApi?.pluginSettings?.showCompleted !== undefined
                           ? pluginApi.pluginSettings.showCompleted
                           : pluginApi?.manifest?.metadata?.defaultSettings?.showCompleted || false;
      loadTodos();
    }
  }

  function loadTodos() {
    todosModel.clear();
    filteredTodosModel.clear();

    var pluginTodos = root.rawTodos;

    for (var i = 0; i < pluginTodos.length; i++) {
      todosModel.append({
                          id: pluginTodos[i].id,
                          text: pluginTodos[i].text,
                          completed: pluginTodos[i].completed === true,
                          createdAt: pluginTodos[i].createdAt
                        });
    }

    for (var k = 0; k < pluginTodos.length; k++) {
      if (showCompleted || !pluginTodos[k].completed) {
        filteredTodosModel.append({
                                    id: pluginTodos[k].id,
                                    text: pluginTodos[k].text,
                                    completed: pluginTodos[k].completed === true,
                                    createdAt: pluginTodos[k].createdAt
                                  });
      }
    }
  }

  onPluginApiChanged: {
    if (pluginApi) {
      loadTodos();
    }
  }

  // Watch for changes in the todos array length or showCompleted setting
  property int previousTodosCount: -1

  Timer {
    id: settingsWatcher
    interval: 200
    running: !!pluginApi
    repeat: true
    onTriggered: {
    var newShowCompleted = pluginApi?.pluginSettings?.showCompleted !== undefined
                           ? pluginApi.pluginSettings.showCompleted
                           : pluginApi?.manifest?.metadata?.defaultSettings?.showCompleted || false;
      var currentTodos = pluginApi?.pluginSettings?.todos || [];
      var currentTodosCount = currentTodos.length;

      if (root.showCompleted !== newShowCompleted || root.previousTodosCount !== currentTodosCount) {
        root.showCompleted = newShowCompleted;
        root.previousTodosCount = currentTodosCount;
        loadTodos();
      }
    }
  }

  Rectangle {
    id: panelContainer
    anchors.fill: parent
    color: Color.transparent

    ColumnLayout {
      anchors {
        fill: parent
        margins: Style.marginM
      }
      spacing: Style.marginL

      Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: Color.mSurfaceVariant
        radius: Style.radiusL

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.marginM
          spacing: Style.marginM

          RowLayout {
            spacing: Style.marginM

            NIcon {
              icon: "checklist"
              pointSize: Style.fontSizeL
            }

            NText {
              text: pluginApi?.tr("panel.header.title")
              font.pointSize: Style.fontSizeL
              font.weight: Font.Medium
              color: Color.mOnSurface
            }

            Item {
              Layout.fillWidth: true
            }

            NButton {
              text: pluginApi?.tr("panel.header.clear_completed_button")
              onClicked: {
                if (pluginApi) {
                  var todos = pluginApi.pluginSettings.todos || [];

                  var activeTodos = todos.filter(todo => !todo.completed);

                  pluginApi.pluginSettings.todos = activeTodos;

                  pluginApi.pluginSettings.count = activeTodos.length;
                  pluginApi.pluginSettings.completedCount = 0;

                  pluginApi.saveSettings();

                  loadTodos();
                }
              }
            }
          }

          Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Color.mSurfaceVariant
            radius: Style.radiusM
            border.color: Color.mOutline
            border.width: 1

            ColumnLayout {
              anchors {
                fill: parent
                margins: Style.marginM
              }
              spacing: Style.marginM

              RowLayout {
                spacing: Style.marginS

                NTextInput {
                  id: newTodoInput
                  placeholderText: pluginApi?.tr("panel.add_todo.placeholder")
                  Layout.fillWidth: true
                  Keys.onReturnPressed: addTodo()
                }

                NButton {
                  text: pluginApi?.tr("panel.add_todo.add_button")
                  onClicked: addTodo()
                }
              }

              ScrollView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                ScrollBar.vertical.policy: ScrollBar.AsNeeded
                ScrollBar.vertical.visible: false
                ListView {
                  id: todoListView
                  model: root.filteredTodosModel
                  spacing: Style.marginS
                  boundsBehavior: Flickable.StopAtBounds
                  flickableDirection: Flickable.VerticalFlick

                  delegate: Rectangle {
                    width: ListView.view.width
                    height: Style.baseWidgetSize
                    color: Color.mSurface
                    radius: Style.radiusS

                    RowLayout {
                      anchors.left: parent.left
                      anchors.right: parent.right
                      anchors.verticalCenter: parent.verticalCenter
                      anchors.leftMargin: Style.marginM
                      anchors.rightMargin: Style.marginM
                      spacing: Style.marginS

                      NToggle {
                        checked: model.completed
                        onToggled: checked => {
                                     if (pluginApi) {
                                       var todos = pluginApi.pluginSettings.todos || [];

                                       for (var i = 0; i < todos.length; i++) {
                                         if (todos[i].id === model.id) {
                                           todos[i].completed = checked;
                                           break;
                                         }
                                       }

                                       pluginApi.pluginSettings.todos = todos;

                                       var completedCount = 0;
                                       for (var j = 0; j < todos.length; j++) {
                                         if (todos[j].completed) {
                                           completedCount++;
                                         }
                                       }
                                       pluginApi.pluginSettings.completedCount = completedCount;

                                       pluginApi.saveSettings();
                                       loadTodos();
                                     }
                                   }
                      }

                      NText {
                        text: model.text
                        color: model.completed ? Color.mOnSurfaceVariant : Color.mOnSurface
                        font.strikeout: model.completed
                        verticalAlignment: Text.AlignVCenter
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                      }
                      Item {
                        id: deleteButtonContainer
                        implicitWidth: Style.baseWidgetSize * 0.6
                        implicitHeight: Style.baseWidgetSize * 0.6

                        NIcon {
                          id: deleteButtonIcon
                          anchors.centerIn: parent
                          icon: "x"
                          pointSize: Style.fontSizeS
                          color: Color.mOnSurfaceVariant
                          opacity: 0.3

                          MouseArea {
                            id: mouseArea
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                              // Directly modify the todos list through pluginApi
                              if (pluginApi) {
                                var todos = pluginApi.pluginSettings.todos || [];
                                var indexToRemove = -1;

                                for (var i = 0; i < todos.length; i++) {
                                  if (todos[i].id === model.id) {
                                    indexToRemove = i;
                                    break;
                                  }
                                }

                                if (indexToRemove !== -1) {
                                  todos.splice(indexToRemove, 1);

                                  pluginApi.pluginSettings.todos = todos;
                                  pluginApi.pluginSettings.count = todos.length;

                                  // Recalculate completed count after removal
                                  var completedCount = 0;
                                  for (var j = 0; j < todos.length; j++) {
                                    if (todos[j].completed) {
                                      completedCount++;
                                    }
                                  }
                                  pluginApi.pluginSettings.completedCount = completedCount;

                                  pluginApi.saveSettings();
                                  loadTodos();
                                } else {
                                  Logger.e("Todo", "Todo with ID " + model.id + " not found for deletion");
                                }
                              } else {
                                Logger.e("Todo", "pluginApi is null, cannot delete todo");
                              }
                            }
                          }

                          states: [
                            State {
                              name: "hovered"
                              when: mouseArea.containsMouse
                              PropertyChanges {
                                target: deleteButtonIcon
                                opacity: 1.0
                                color: Color.mError
                              }
                            }
                          ]

                          transitions: [
                            Transition {
                              from: "*"; to: "hovered"
                              NumberAnimation { properties: "opacity"; duration: 150 }
                            },
                            Transition {
                              from: "hovered"; to: "*"
                              NumberAnimation { properties: "opacity"; duration: 150 }
                            }
                          ]
                        }
                      }
                    }
                  }

                  highlightRangeMode: ListView.NoHighlightRange
                  preferredHighlightBegin: 0
                  preferredHighlightEnd: 0

                  header: Item {
                    width: ListView.view.width
                    height: root.todosModel.count === 0 ? contentText.implicitHeight + Style.marginL * 2 : 0

                    NText {
                      id: contentText
                      anchors.centerIn: parent
                      text: root.todosModel.count === 0 ? pluginApi?.tr("panel.empty_state.message") : ""
                      color: Color.mOnSurfaceVariant
                      font.pointSize: Style.fontSizeM
                      font.weight: Font.Normal
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

  function addTodo() {
    if (newTodoInput.text.trim() !== "") {
      if (pluginApi) {
        var todos = pluginApi.pluginSettings.todos || [];

        var newTodo = {
          id: Date.now() // Use timestamp as simple ID
              ,
          text: newTodoInput.text.trim(),
          completed: false,
          createdAt: new Date().toISOString()
        };

        todos.push(newTodo);

        pluginApi.pluginSettings.todos = todos;

        pluginApi.pluginSettings.count = todos.length;

        pluginApi.saveSettings();

        newTodoInput.text = "";
        loadTodos(); // Reload todos to update view
      }
    }
  }
}

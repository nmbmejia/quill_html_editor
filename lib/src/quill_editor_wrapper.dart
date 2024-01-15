import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:quill_html_editor/quill_html_editor.dart';
import 'package:quill_html_editor/src/utils/hex_color.dart';
import 'package:quill_html_editor/src/utils/string_util.dart';
import 'package:quill_html_editor/src/widgets/edit_table_drop_down.dart';
import 'package:quill_html_editor/src/widgets/webviewx/src/webviewx_plus.dart';

/// A typedef representing a loading builder function.
///
/// A [LoadingBuilder] is a function that takes a [BuildContext] as an argument
/// and returns a [Widget]. It is typically used in conjunction with asynchronous
/// operations or data fetching, allowing you to display a loading indicator or
/// any other UI element during the loading process.
typedef LoadingBuilder = Widget Function(BuildContext context);

///[QuillHtmlEditor] widget to display the quill editor,
class QuillHtmlEditor extends StatefulWidget {
  ///[QuillHtmlEditor] widget to display the quill editor,
  ///pass the controller to access the editor methods
  QuillHtmlEditor({
    this.text,
    required this.controller,
    required this.minHeight,
    this.isEnabled = true,
    this.onTextChanged,
    this.backgroundColor = Colors.white,
    this.hintText = 'Start typing something amazing',
    this.onFocusChanged,
    this.onEditorCreated,
    this.onSelectionChanged,
    this.padding = EdgeInsets.zero,
    this.hintTextPadding = EdgeInsets.zero,
    this.hintTextAlign = TextAlign.start,
    this.onEditorResized,
    this.onEditingComplete,
    this.ensureVisible = false,
    this.loadingBuilder,
    this.inputAction = InputAction.newline,
    this.autoFocus = false,
    this.textStyle = const TextStyle(
      fontStyle: FontStyle.normal,
      fontSize: 20.0,
      color: Colors.black87,
      fontWeight: FontWeight.normal,
    ),
    this.hintTextStyle = const TextStyle(
      fontStyle: FontStyle.normal,
      fontSize: 20.0,
      color: Colors.black87,
      fontWeight: FontWeight.normal,
    ),
  }) : super(key: controller._editorKey);

  /// [text] to set initial text to the editor, please use text
  /// We can also use the setText method for the same
  final String? text;

  /// [minHeight] to define the minimum height of the editor
  final double minHeight;

  /// [hintText] is a placeholder, by default, the hint will be 'Description'
  /// We can override the placeholder text by passing hintText to the editor
  final String? hintText;

  /// [isEnabled] as the name suggests, is used to enable or disable the editor
  /// When it is set to false, the user cannot edit or type in the editor
  final bool isEnabled;

  /// [controller] to access all the methods of editor and toolbar
  final QuillEditorController controller;

  /// [onTextChanged] callback function that triggers on text changed
  final Function(String)? onTextChanged;

  /// [onEditingComplete] callback function that triggers on editing completed
  final Function(String)? onEditingComplete;

  ///[backgroundColor] to set the background color of the editor
  final Color backgroundColor;

  ///[onFocusChanged] method returns a boolean value, if the editor has focus,
  ///it will return true; if not, will return false
  final Function(bool)? onFocusChanged;

  ///[onSelectionChanged] method returns SelectionModel, which has index and
  ///length of the selected text
  final Function(SelectionModel)? onSelectionChanged;

  ///[onEditorResized] method returns height of the widget on resize,
  final Function(double)? onEditorResized;

  ///[onEditorCreated] a callback method triggered once the editor is created
  ///it will be called only once after editor is loaded completely
  final VoidCallback? onEditorCreated;

  ///[textStyle] optional style for the default editor text,
  ///while all fields in the style are not mapped;Some basic fields like,
  ///fontStyle, fontSize, color,fontWeight can be applied
  ///font family support is not available yet
  final TextStyle? textStyle;

  ///[padding] optional style to set padding to the editor's text,
  /// default padding will be EdgeInsets.zero
  final EdgeInsets? padding;

  ///[hintTextStyle] optional style for the hint text styepe,
  ///while all fields in the style are not mapped;Some basic fields like,
  ///fontStyle, fontSize, color,fontWeight can be applied
  ///font family support is not available yet
  final TextStyle? hintTextStyle;

  ///[hintTextAlign] optional style to align the editor's hint text
  /// default value is hintTextAlign.start
  final TextAlign? hintTextAlign;

  ///[hintTextPadding] optional style to set padding to the editor's text,
  /// default padding will be EdgeInsets.zero
  final EdgeInsets? hintTextPadding;

  /// [ensureVisible] by default it will be set to false, set it to true to
  /// make sure the focus area of the editor is visible.
  /// Note:  Please make sure to wrap the editor with SingleChildScrollView, to make the
  /// editor scrollable.
  final bool? ensureVisible;

  /// A builder function that provides a widget to display while the data is loading.
  ///
  /// The [loadingBuilder] is responsible for creating a widget that represents the
  /// loading state of the custom widget. It is called when the data is being fetched
  /// or processed, allowing you to display a loading indicator or any other UI element
  /// that indicates the ongoing operation.
  final LoadingBuilder? loadingBuilder;

  /// Represents an optional input action within a specific context.
  ///
  /// An instance of this class holds an optional [InputAction] value, which can be either
  /// [InputAction.newline] indicating a line break or [InputAction.send] indicating
  /// that the input content should be sent or submitted.
  final InputAction? inputAction;

  /// [autoFocus] Whether the widget should automatically request focus when it is inserted
  /// into the widget tree. If set to `true`, the widget will request focus
  /// immediately after being built and inserted into the tree. If set to `false`,
  /// it will not request focus automatically.
  ///
  /// The default value is `false`
  /// **Note** due to limitations of flutter webview at the moment, focus doesn't launch the keyboard in mobile, however, it will set the cursor at the end on focus.
  final bool? autoFocus;

  @override
  QuillHtmlEditorState createState() => QuillHtmlEditorState();
}

///[QuillHtmlEditorState] editor state class to render the editor
class QuillHtmlEditorState extends State<QuillHtmlEditor> {
  /// it is the controller used to access the functions of quill js library
  late WebViewXController _webviewController;

  /// this variable is used to set the html code that renders the quill js library
  String _initialContent = "";

  /// [isEnabled] as the name suggests, is used to enable or disable the editor
  /// When it is set to false, the user cannot edit or type in the editor
  bool isEnabled = true;

  late double _currentHeight;
  bool _hasFocus = false;
  String _quillJsScript = '';
  late Future _loadScripts;
  late String _fontFamily;
  late String _encodedStyle;
  bool _editorLoaded = false;
  @override
  initState() {
    _loadScripts = rootBundle.loadString(
        'packages/quill_html_editor/assets/scripts/quill_2.0.0_4_min.js');
    _fontFamily = widget.textStyle?.fontFamily ?? 'Roboto';
    _encodedStyle = Uri.encodeFull(_fontFamily);
    isEnabled = widget.isEnabled;
    _currentHeight = widget.minHeight;

    super.initState();
  }

  @override
  void dispose() {
    _webviewController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
        future: _loadScripts,
        builder: (context, snap) {
          if (snap.hasData) {
            _quillJsScript = snap.data!;
          }
          if (snap.connectionState == ConnectionState.done) {
            return LayoutBuilder(builder: (context, constraints) {
              _initialContent = _getQuillPage(width: constraints.maxWidth);
              return _buildEditorView(
                  context: context, width: constraints.maxWidth);
            });
          }

          if (widget.loadingBuilder != null) {
            return widget.loadingBuilder!(context);
          } else {
            return SizedBox(
              height: widget.minHeight,
              child: const Center(
                child: CircularProgressIndicator(
                  strokeWidth: 0.3,
                ),
              ),
            );
          }
        });
  }

  Widget _buildEditorView(
      {required BuildContext context, required double width}) {
    _initialContent = _getQuillPage(width: width);
    return Stack(
      children: [
        WebViewX(
          key: ValueKey(widget.controller.toolBarKey.hashCode.toString()),
          initialContent: _initialContent,
          initialSourceType: SourceType.html,
          height: _currentHeight,
          onPageStarted: (s) {
            _editorLoaded = false;
          },
          ignoreAllGestures: false,
          width: width,
          onWebViewCreated: (controller) => _webviewController = controller,
          onPageFinished: (src) {
            Future.delayed(const Duration(milliseconds: 100)).then((value) {
              _editorLoaded = true;
              debugPrint('_editorLoaded $_editorLoaded');
              if (mounted) {
                setState(() {});
              }
              widget.controller.enableEditor(isEnabled);
              if (widget.text != null) {
                _setHtmlTextToEditor(htmlText: widget.text!);
              }
              if (widget.autoFocus == true) {
                widget.controller.focus();
              }
              if (widget.onEditorCreated != null) {
                widget.onEditorCreated!();
              }
              widget.controller._editorLoadedController?.add('');
            });
          },
          dartCallBacks: {
            DartCallback(
                name: 'EditorResizeCallback',
                callBack: (height) {
                  if (_currentHeight == double.tryParse(height.toString())) {
                    return;
                  }
                  try {
                    _currentHeight =
                        double.tryParse(height.toString()) ?? widget.minHeight;
                  } catch (e) {
                    _currentHeight = widget.minHeight;
                  } finally {
                    if (mounted) {
                      setState(() => _currentHeight);
                    }
                    if (widget.onEditorResized != null) {
                      widget.onEditorResized!(_currentHeight);
                    }
                  }
                }),
            DartCallback(
                name: 'UpdateFormat',
                callBack: (map) {
                  try {
                    if (widget.controller._toolBarKey != null) {
                      widget.controller._toolBarKey!.currentState
                          ?.updateToolBarFormat(jsonDecode(map));
                    }
                  } catch (e) {
                    if (!kReleaseMode) {
                      debugPrint(e.toString());
                    }
                  }
                }),
            DartCallback(
                name: 'OnTextChanged',
                callBack: (map) {
                  var tempText = "";
                  if (tempText == map) {
                    return;
                  } else {
                    tempText = map;
                  }
                  try {
                    if (widget.controller._changeController != null) {
                      String finalText = "";
                      String parsedText =
                          QuillEditorController._stripHtmlIfNeeded(map);
                      if (parsedText.trim() == "") {
                        finalText = "";
                      } else {
                        finalText = map;
                      }
                      if (widget.onTextChanged != null) {
                        widget.onTextChanged!(finalText);
                      }
                      widget.controller._changeController!.add(finalText);
                    }
                  } catch (e) {
                    if (!kReleaseMode) {
                      debugPrint(e.toString());
                    }
                  }
                }),
            DartCallback(
                name: 'FocusChanged',
                callBack: (map) {
                  _hasFocus = map?.toString() == 'true';
                  if (widget.onFocusChanged != null) {
                    widget.onFocusChanged!(_hasFocus);
                  }

                  /// scrolls to the end of the text area, to keep the focus visible
                  if (widget.ensureVisible == true && _hasFocus) {
                    Scrollable.of(context).position.ensureVisible(
                        context.findRenderObject()!,
                        duration: const Duration(milliseconds: 300),
                        alignmentPolicy:
                            ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
                        curve: Curves.fastLinearToSlowEaseIn);
                  }
                }),
            DartCallback(
                name: 'OnEditingCompleted',
                callBack: (map) {
                  var tempText = "";
                  if (tempText == map) {
                    return;
                  } else {
                    tempText = map;
                  }
                  try {
                    if (widget.controller._changeController != null) {
                      String finalText = "";
                      String parsedText =
                          QuillEditorController._stripHtmlIfNeeded(map);
                      if (parsedText.trim() == "") {
                        finalText = "";
                      } else {
                        finalText = map;
                      }
                      if (widget.onEditingComplete != null) {
                        widget.onEditingComplete!(finalText);
                      }
                      widget.controller._changeController!.add(finalText);
                    }
                  } catch (e) {
                    if (!kReleaseMode) {
                      debugPrint(e.toString());
                    }
                  }
                }),
            DartCallback(
                name: 'OnSelectionChanged',
                callBack: (selection) {
                  try {
                    if (widget.onSelectionChanged != null) {
                      if (!_hasFocus) {
                        if (widget.onFocusChanged != null) {
                          _hasFocus = true;
                          widget.onFocusChanged!(_hasFocus);
                        }
                      }
                      widget.onSelectionChanged!(selection != null
                          ? SelectionModel.fromJson(jsonDecode(selection))
                          : SelectionModel(index: 0, length: 0));
                    }
                  } catch (e) {
                    if (!kReleaseMode) {
                      debugPrint(e.toString());
                    }
                  }
                }),

            /// callback to notify once editor is completely loaded
            DartCallback(
                name: 'EditorLoaded',
                callBack: (map) {
                  _editorLoaded = true;
                  if (mounted) {
                    setState(() {});
                  }
                }),
          },
          webSpecificParams: const WebSpecificParams(
            printDebugInfo: false,
          ),
          mobileSpecificParams: const MobileSpecificParams(
            androidEnableHybridComposition: true,
          ),
        ),
        Visibility(
            visible: !_editorLoaded,
            child: widget.loadingBuilder != null
                ? widget.loadingBuilder!(context)
                : SizedBox(
                    height: widget.minHeight,
                    child: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 0.3,
                      ),
                    ),
                  ))
      ],
    );
  }

  /// a private method to get the Html text from the editor
  Future<String> _getHtmlFromEditor() async {
    return await _webviewController.callJsMethod("getHtmlText", []);
  }

  /// a private method to get the Plain text from the editor
  Future<String> _getPlainTextFromEditor() async {
    return await _webviewController.callJsMethod("getPlainText", []);
  }

  /// a private method to get the delta  from the editor
  Future<String> _getDeltaFromEditor() async {
    return await _webviewController.callJsMethod("getDelta", []);
  }

  /// a private method to check if editor has focus
  Future<int> _getSelectionCount() async {
    return await _webviewController.callJsMethod("getSelection", []);
  }

  /// a private method to check if editor has focus
  Future<dynamic> _getSelectionRange() async {
    return await _webviewController.callJsMethod("getSelectionRange", []);
  }

  /// a private method to check if editor has focus
  Future<dynamic> _setSelectionRange(int index, int length) async {
    return await _webviewController
        .callJsMethod("setSelection", [index, length]);
  }

  /// a private method to set the Html text to the editor
  Future _setHtmlTextToEditor({required String htmlText}) async {
    return await _webviewController.callJsMethod("setHtmlText", [htmlText]);
  }

  /// a private method to set the Delta  text to the editor
  Future _setDeltaToEditor({required Map<dynamic, dynamic> deltaMap}) async {
    return await _webviewController
        .callJsMethod("setDeltaContent", [jsonEncode(deltaMap)]);
  }

  /// a private method to request focus to the editor
  Future _requestFocus() async {
    return await _webviewController.callJsMethod("requestFocus", []);
  }

  /// a private method to un focus the editor
  Future _unFocus() async {
    return await _webviewController.callJsMethod("unFocus", []);
  }

  /// a private method to insert the Html text to the editor
  Future _insertHtmlTextToEditor({required String htmlText, int? index}) async {
    return await _webviewController
        .callJsMethod("insertHtmlText", [htmlText, index]);
  }

  /// a private method to embed the video to the editor
  Future _embedVideo({required String videoUrl}) async {
    return await _webviewController.callJsMethod("embedVideo", [videoUrl]);
  }

  /// a private method to embed the image to the editor
  Future _embedImage({required String imgSrc}) async {
    return await _webviewController.callJsMethod("embedImage", [imgSrc]);
  }

  /// a private method to enable/disable the editor
  Future _enableTextEditor({required bool isEnabled}) async {
    return await _webviewController.callJsMethod("enableEditor", [isEnabled]);
  }

  /// a private method to enable/disable the editor
  Future _setFormat({required String format, required dynamic value}) async {
    try {
      return await _webviewController
          .callJsMethod("setFormat", [format, value]);
    } catch (e) {
      _printWrapper(false, e.toString());
    }
  }

  /// a private method to insert table by row and column to the editor
  Future _insertTableToEditor({required int row, required int column}) async {
    return await _webviewController.callJsMethod("insertTable", [row, column]);
  }

  /// a private method to add remove or delete table in the editor
  Future _modifyTable(EditTableEnum type) async {
    return await _webviewController
        .callJsMethod("modifyTable", [describeEnum(type)]);
  }

  /// a private method to replace selection text in the editor
  Future _replaceText(
    String replaceText,
  ) async {
    return await _webviewController
        .callJsMethod("replaceSelection", [replaceText]);
  }

  /// a private method to get the selected text from editor
  Future _getSelectedText() async {
    return await _webviewController.callJsMethod("getSelectedText", []);
  }

  /// a private method to get the selected html text from editor
  Future _getSelectedHtmlText() async {
    return await _webviewController.callJsMethod("getSelectionHtml", []);
  }

  /// a private method to undo the history
  Future _undo() async {
    return await _webviewController.callJsMethod("undo", []);
  }

  /// a private method to redo the history
  Future _redo() async {
    return await _webviewController.callJsMethod("redo", []);
  }

  /// a private method to clear the history stack
  Future _clearHistory() async {
    return await _webviewController.callJsMethod("clearHistory", []);
  }

  /// This method generated the html code that is required to render the quill js editor
  /// We are rendering this html page with the help of webviewx and using the callbacks to call the quill js apis
  String _getQuillPage({required double width}) {
    return '''
   <!DOCTYPE html>
        <html>
        <head>
        <link href="https://fonts.googleapis.com/css?family=$_encodedStyle:400,400i,700,700i" rel="stylesheet">
        <meta name="viewport" content="width=device-width, initial-scale=1, minimum-scale=1, maximum-scale=1">    
        
       <!-- Include the Quill library --> 
       <script src="https://cdn.quilljs.com/1.3.6/quill.js"></script>
       ''';
  }
}

///[QuillEditorController] controller constructor to generate editor, toolbar state keys
class QuillEditorController {
  GlobalKey<QuillHtmlEditorState>? _editorKey;
  GlobalKey<ToolBarState>? _toolBarKey;
  StreamController<String>? _changeController;
  StreamController<String>? _editorLoadedController;

  ///[isEnable] to enable/disable editor
  bool isEnable = true;

  /// A controller for the Quill editor.
  ///
  /// The [QuillEditorController] class provides control over the Quill editor by managing its state
  /// and providing methods to interact with the editor's content and toolbar.
  ///
  QuillEditorController() {
    _editorKey =
        GlobalKey<QuillHtmlEditorState>(debugLabel: _getRandomString(15));
    _toolBarKey = GlobalKey<ToolBarState>(debugLabel: _getRandomString(15));
    _changeController = StreamController<String>();
    _editorLoadedController = StreamController<String>();
  }

  /// to access toolbar key from toolbar widget
  GlobalKey<ToolBarState>? get toolBarKey => _toolBarKey;

  /// [getText] method is used to get the html string from the editor
  /// To avoid getting empty html tags, we are validating the html string
  /// if it doesn't contain any text, the method will return empty string instead of empty html tag
  Future<String> getText() async {
    try {
      String? text = await _editorKey?.currentState?._getHtmlFromEditor();
      if (text == '<p><br></p>') {
        return text!.replaceAll('<p><br></p>', '');
      }
      return text ?? '';
    } catch (e) {
      return "";
    }
  }

  /// Retrieves the plain text content from the editor.
  ///
  /// The [getPlainText] method is used to extract the plain text content from the editor
  /// as a [String]. This can be useful when you need to retrieve the editor's content
  /// without any formatting or HTML tags.
  ///
  Future<String> getPlainText() async {
    try {
      String? text = await _editorKey?.currentState?._getPlainTextFromEditor();
      if (text == null) {
        return "";
      } else {
        return text;
      }
    } catch (e) {
      return "";
    }
  }

  /// Sets the HTML text content in the editor.
  ///
  /// The [setText] method is used to set the HTML text content in the editor,
  /// overriding any existing text with the new content.
  Future setText(String text) async {
    return await _editorKey?.currentState?._setHtmlTextToEditor(htmlText: text);
  }

  /// Sets the Delta object in the editor.
  ///
  /// The [setDelta] method is used to set the Delta object in the editor,
  /// overriding any existing text with the new content.
  Future setDelta(Map delta) async {
    return await _editorKey?.currentState?._setDeltaToEditor(deltaMap: delta);
  }

  /// Retrieves the Delta map from the editor.
  ///
  /// The [getDelta] method is used to retrieve the Delta map from the editor
  /// as a [Map]. The Delta map represents the content and formatting of the editor.
  ///
  Future<Map> getDelta() async {
    var text = await _editorKey?.currentState?._getDeltaFromEditor();
    return jsonDecode(text.toString());
  }

  /// Requests focus for the editor.
  ///
  /// The [focus] method is used to request focus for the editor,
  /// bringing it into the active input state.
  ///
  Future focus() async {
    return await _editorKey?.currentState?._requestFocus();
  }

  /// Inserts a table into the editor.
  ///
  /// The [insertTable] method is used to insert a table into the editor
  /// with the specified number of rows and columns.
  ///
  Future insertTable(int row, int column) async {
    return await _editorKey?.currentState
        ?._insertTableToEditor(row: row, column: column);
  }

  /// Modifies an existing table in the editor.
  ///
  /// The [modifyTable] method is used to add or remove rows or columns of an existing table in the editor.
  ///
  Future modifyTable(EditTableEnum type) async {
    return await _editorKey?.currentState?._modifyTable(type);
  }

  /// Inserts HTML text into the editor.
  ///
  /// The [insertText] method is used to insert HTML text into the editor.
  /// If the [index] parameter is not specified, the text will be inserted at the current cursor position.
  ///
  Future insertText(String text, {int? index}) async {
    return await _editorKey?.currentState
        ?._insertHtmlTextToEditor(htmlText: text, index: index);
  }

  /// Replaces the selected text in the editor.
  ///
  /// The [replaceText] method is used to replace the currently selected text in the editor
  /// with the specified HTML text.
  ///
  /// custom format for replaced text will come in future release
  Future replaceText(String text) async {
    return await _editorKey?.currentState?._replaceText(text);
  }

  /// [getSelectedText] method to get the selected text from editor
  Future getSelectedText() async {
    return await _editorKey?.currentState?._getSelectedText();
  }

  /// [getSelectedHtmlText] method to get the selected html text from editor
  Future getSelectedHtmlText() async {
    return await _editorKey?.currentState?._getSelectedHtmlText();
  }

  /// [embedVideo] method is used to embed url of video to the editor
  Future embedVideo(String url) async {
    String? link = StringUtil.sanitizeVideoUrl(url);
    if (link == null) {
      return;
    }
    return await _editorKey?.currentState?._embedVideo(videoUrl: link);
  }

  /// [embedImage] method is used to insert image to the editor
  Future embedImage(String imgSrc) async {
    return await _editorKey?.currentState?._embedImage(imgSrc: imgSrc);
  }

  /// [enableEditor] method is used to enable/ disable the editor,
  /// while, we can enable or disable the editor directly by passing isEnabled to the widget,
  /// this is an additional function that can be used to do the same with the state key
  /// We can choose either of these ways to enable/disable
  void enableEditor(bool enable) async {
    isEnable = enable;
    await _editorKey?.currentState?._enableTextEditor(isEnabled: enable);
  }

  @Deprecated(
      'Please use onFocusChanged method in the QuillHtmlEditor widget for focus')

  /// [hasFocus]checks if the editor has focus, returns the selection string length
  Future<int> hasFocus() async {
    return (await _editorKey?.currentState?._getSelectionCount()) ?? 0;
  }

  /// [getSelectionRange] to get the text selection range from editor
  Future<SelectionModel> getSelectionRange() async {
    var selection = await _editorKey?.currentState?._getSelectionRange();
    return selection != null
        ? SelectionModel.fromJson(jsonDecode(selection))
        : SelectionModel(index: 0, length: 0);
  }

  /// [setSelectionRange] to select the text in the editor by index
  Future setSelectionRange(int index, int length) async {
    return await _editorKey?.currentState?._setSelectionRange(index, length);
  }

  ///  [clear] method is used to clear the editor
  void clear() async {
    await _editorKey?.currentState?._setHtmlTextToEditor(htmlText: '');
  }

  /// [requestFocus] method is to request focus of the editor
  void requestFocus() async {
    await _editorKey?.currentState?._requestFocus();
  }

  ///  [unFocus] method is to un focus the editor
  void unFocus() async {
    await _editorKey?.currentState?._unFocus();
  }

  ///[setFormat]  sets the format to editor either by selection or by cursor position
  void setFormat({required String format, required dynamic value}) async {
    _editorKey?.currentState?._setFormat(format: format, value: value);
  }

  ///[onTextChanged] method is used to listen to editor text changes
  void onTextChanged(Function(String) data) {
    try {
      if (_changeController != null &&
          _changeController?.hasListener == false) {
        _changeController?.stream.listen((event) {
          data(event);
        });
      }
    } catch (e) {
      if (!kReleaseMode) {
        debugPrint(e.toString());
      }
    }

    return;
  }

  /// Callback function triggered when the editor is completely loaded.
  ///
  /// The [onEditorLoaded] callback function is called when the Quill editor is fully loaded and ready for user interaction.
  /// It provides an opportunity to perform actions or initialize any additional functionality once the editor is loaded.
  ///
  void onEditorLoaded(VoidCallback callback) {
    try {
      if (_editorLoadedController != null &&
          _editorLoadedController?.hasListener == false) {
        _editorLoadedController?.stream.listen((event) {
          callback();
        });
      }
    } catch (e) {
      if (!kReleaseMode) {
        debugPrint(e.toString());
      }
    }

    return;
  }

  ///[dispose] dispose function to close the stream
  void dispose() {
    _changeController?.close();
    _editorLoadedController?.close();
  }

  /// it is a regex method to remove the tags and replace them with empty space
  static String _stripHtmlIfNeeded(String text) {
    return text.replaceAll(RegExp(r'<[^>]*>|&[^;]+;'), ' ');
  }

  ///  [undo] method to undo the changes in editor
  void undo() async {
    await _editorKey?.currentState?._undo();
  }

  ///  [redo] method to redo the changes in editor
  void redo() async {
    await _editorKey?.currentState?._redo();
  }

  ///  [clearHistory] method to clear the history stack of editor
  void clearHistory() async {
    await _editorKey?.currentState?._clearHistory();
  }
}

///[SelectionModel] a model class for selection range
class SelectionModel {
  /// [index] index of the cursor
  int? index;

  ///[length] length of the selected value
  int? length;

  ///[SelectionModel] a model class constructor for selection range
  SelectionModel({this.index, this.length});

  ///[SelectionModel.fromJson] extension method to get selection model from json
  SelectionModel.fromJson(Map<String, dynamic> json) {
    index = json['index'];
    length = json['length'];
  }
}

void _printWrapper(bool showPrint, String text) {
  if (showPrint) {
    debugPrint(text);
  }
}

const _chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
Random _rnd = Random();

String _getRandomString(int length) => String.fromCharCodes(Iterable.generate(
    length, (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length))));

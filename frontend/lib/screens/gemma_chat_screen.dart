// import 'dart:io';
// import 'package:flutter/material.dart';
// import 'package:flutter_llama/flutter_llama.dart';
// import 'package:path_provider/path_provider.dart';
//
// // ── Message model ─────────────────────────────────────────────────────────────
// enum _Role { user, bot, error }
//
// class _Msg {
//   final _Role role;
//   String text;
//   _Msg(this.role, this.text);
// }
//
// // ── Screen ────────────────────────────────────────────────────────────────────
// class GemmaChatScreen extends StatefulWidget {
//   const GemmaChatScreen({super.key});
//
//   @override
//   State<GemmaChatScreen> createState() => _GemmaChatScreenState();
// }
//
// class _GemmaChatScreenState extends State<GemmaChatScreen> {
//   // ── deps ────────────────────────────────────────────────────────────────────
//   final _llama       = FlutterLlama.instance;
//   final _inputCtrl   = TextEditingController();
//   final _scrollCtrl  = ScrollController();
//
//   // ── state ───────────────────────────────────────────────────────────────────
//   final List<_Msg> _messages = [];
//   bool   _modelLoaded   = false;
//   bool   _loading        = false;   // true while model is being loaded
//   bool   _generating     = false;   // true while tokens are streaming
//   String _statusText     = '';
//
//   // ── lifecycle ────────────────────────────────────────────────────────────────
//   @override
//   void initState() {
//     super.initState();
//
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       _loadModel();
//     });
//   }
//
//   @override
//   void dispose() {
//     _llama.unloadModel();
//     _inputCtrl.dispose();
//     _scrollCtrl.dispose();
//     super.dispose();
//   }
//
//   // ── model loading ─────────────────────────────────────────────────────────────
//   Future<void> _loadModel() async {
//     setState(() {
//       _loading    = true;
//       _statusText = 'Locating model file…';
//     });
//
//     final path = await _resolveModelPath();
//     if (path == null) {
//       setState(() {
//         _loading    = false;
//         _statusText =
//         'Model file not found.\n\n'
//             'Push it to your device once:\n\n'
//             'adb push gemma-2b.gguf\n      /sdcard/Download/gemma-2b.gguf\n\n'
//             'Then restart the app.';
//       });
//       return;
//     }
//
//     setState(() => _statusText = 'Loading Gemma into memory…\n(first load takes ~30 s)');
//
//     try {
//       // flutter_llama API — LlamaConfig + loadModel
//       final config = LlamaConfig(
//         modelPath:   path,
//         nThreads:    4,
//         nGpuLayers:  0,       // CPU-only; safe on all devices
//         contextSize: 2048,
//         batchSize:   512,
//         useGpu:      false,
//         verbose:     false,
//       );
//
//       final ok = await _llama.loadModel(config);
//       if (!ok) throw Exception('loadModel returned false');
//
//       setState(() {
//         _modelLoaded = true;
//         _loading     = false;
//         _statusText  = '';
//       });
//
//       _addMsg(_Role.bot,
//           '👋 Gemma is running offline on your device!\n'
//               'Ask me anything.');
//     } catch (e) {
//       setState(() {
//         _loading    = false;
//         _statusText = 'Failed to load model:\n$e';
//       });
//     }
//   }
//
//   // Looks for the GGUF in app-private storage first,
//   // then checks /sdcard/Download and auto-copies it.
//   Future<String?> _resolveModelPath() async {
//     final docs    = await getApplicationDocumentsDirectory();
//     final appPath = '${docs.path}/gemma-2b.gguf';
//
//     if (File(appPath).existsSync()) return appPath;
//
//     if (Platform.isAndroid) {
//       for (final src in [
//         '/sdcard/Download/gemma.gguf',
//         '/storage/emulated/0/Download/gemma.gguf',
//       ]) {
//         if (File(src).existsSync()) {
//           setState(() => _statusText = 'Copying model to app storage… (once only)');
//           await File(src).copy(appPath);
//           return appPath;
//         }
//       }
//     }
//     return null;
//   }
//
//   // ── send message ──────────────────────────────────────────────────────────────
//   Future<void> _send() async {
//     final text = _inputCtrl.text.trim();
//     if (text.isEmpty || !_modelLoaded || _generating) return;
//
//     _inputCtrl.clear();
//     _addMsg(_Role.user, text);
//
//     // Placeholder bot message that will be filled token-by-token
//     final botMsg = _Msg(_Role.bot, '');
//     setState(() {
//       _messages.add(botMsg);
//       _generating = true;
//     });
//     _scrollToBottom();
//
//     try {
//       // Build a simple chat-style prompt Gemma understands
//       final prompt = '<start_of_turn>user\n$text<end_of_turn>\n<start_of_turn>model\n';
//
//       final params = GenerationParams(
//         prompt:        prompt,
//         temperature:   0.7,
//         topP:          0.9,
//         topK:          40,
//         maxTokens:     512,
//         repeatPenalty: 1.1,
//         stopSequences: ['<end_of_turn>', '<start_of_turn>'],
//       );
//
//       // flutter_llama streaming — yields one token at a time
//       await for (final token in _llama.generateStream(params)) {
//         if (!mounted) break;
//         setState(() => botMsg.text += token);
//         _scrollToBottom();
//       }
//     } catch (e) {
//       setState(() => botMsg.text = '⚠️ Error: $e');
//       botMsg.role == _Role.error;
//     } finally {
//       if (mounted) setState(() => _generating = false);
//     }
//   }
//
//   // ── helpers ───────────────────────────────────────────────────────────────────
//   void _addMsg(_Role role, String text) {
//     setState(() => _messages.add(_Msg(role, text)));
//     _scrollToBottom();
//   }
//
//   void _scrollToBottom() {
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (_scrollCtrl.hasClients) {
//         _scrollCtrl.animateTo(
//           _scrollCtrl.position.maxScrollExtent,
//           duration: const Duration(milliseconds: 200),
//           curve: Curves.easeOut,
//         );
//       }
//     });
//   }
//
//   Future<void> _clearChat() async {
//     setState(() {
//       _messages.clear();
//       _modelLoaded = false;
//       _loading     = false;
//     });
//     await _llama.unloadModel();
//     _loadModel();
//   }
//
//   // ── build ─────────────────────────────────────────────────────────────────────
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: const Color(0xFFF2F2ED),
//       appBar: _buildAppBar(),
//       body: Column(
//         children: [
//           if (_loading || (!_modelLoaded && _statusText.isNotEmpty))
//             _buildBanner(),
//           Expanded(child: _buildMessageList()),
//           _buildInputBar(),
//         ],
//       ),
//     );
//   }
//
//   AppBar _buildAppBar() {
//     return AppBar(
//       backgroundColor: const Color(0xFF2D6A4F),
//       foregroundColor: Colors.white,
//       elevation: 0,
//       title: Row(children: [
//         const Icon(Icons.psychology_outlined, size: 20),
//         const SizedBox(width: 8),
//         const Text('Gemma AI',
//             style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
//         const SizedBox(width: 8),
//         Container(
//           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
//           decoration: BoxDecoration(
//             color: Colors.white.withOpacity(0.2),
//             borderRadius: BorderRadius.circular(10),
//           ),
//           child: const Text('OFFLINE',
//               style: TextStyle(
//                   fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 0.8)),
//         ),
//         const Spacer(),
//         if (_modelLoaded)
//           Container(
//             width: 8, height: 8,
//             decoration: const BoxDecoration(
//                 color: Color(0xFF52D788), shape: BoxShape.circle),
//           ),
//       ]),
//       actions: [
//         if (_modelLoaded)
//           IconButton(
//             icon: const Icon(Icons.refresh_rounded),
//             tooltip: 'New chat',
//             onPressed: _clearChat,
//           ),
//       ],
//     );
//   }
//
//   Widget _buildBanner() {
//     final isError = !_loading && _statusText.isNotEmpty;
//     return Container(
//       width: double.infinity,
//       color: isError
//           ? Colors.red.shade50
//           : const Color(0xFF2D6A4F).withOpacity(0.07),
//       padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
//       child: Column(children: [
//         if (_loading) ...[
//           const SizedBox(
//             width: 22, height: 22,
//             child: CircularProgressIndicator(
//                 strokeWidth: 2.5, color: Color(0xFF2D6A4F)),
//           ),
//           const SizedBox(height: 10),
//         ],
//         Text(
//           _statusText,
//           textAlign: TextAlign.center,
//           style: TextStyle(
//             fontSize: 13,
//             height: 1.6,
//             color: isError
//                 ? Colors.red.shade700
//                 : const Color(0xFF1B4332),
//             fontFamily: isError ? null : 'monospace',
//           ),
//         ),
//       ]),
//     );
//   }
//
//   Widget _buildMessageList() {
//     if (_messages.isEmpty) {
//       return Center(
//         child: Column(mainAxisSize: MainAxisSize.min, children: [
//           Icon(Icons.chat_bubble_outline_rounded,
//               size: 60, color: Colors.grey.shade300),
//           const SizedBox(height: 14),
//           Text('Gemma is ready — say anything',
//               style: TextStyle(
//                   fontSize: 15, color: Colors.grey.shade500,
//                   fontWeight: FontWeight.w500)),
//           const SizedBox(height: 6),
//           Text('100% offline • no internet needed',
//               style: TextStyle(fontSize: 12, color: Colors.grey.shade400)),
//         ]),
//       );
//     }
//     return ListView.builder(
//       controller: _scrollCtrl,
//       padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
//       itemCount: _messages.length,
//       itemBuilder: (_, i) => _buildBubble(_messages[i]),
//     );
//   }
//
//   Widget _buildBubble(_Msg msg) {
//     final isUser = msg.role == _Role.user;
//     final isErr  = msg.role == _Role.error;
//
//     return Align(
//       alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
//       child: Container(
//         margin: EdgeInsets.only(
//           bottom: 10,
//           left:  isUser ? 56 : 0,
//           right: isUser ? 0  : 56,
//         ),
//         padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
//         decoration: BoxDecoration(
//           color: isUser
//               ? const Color(0xFF2D6A4F)
//               : isErr
//               ? Colors.red.shade50
//               : Colors.white,
//           borderRadius: BorderRadius.only(
//             topLeft:     const Radius.circular(18),
//             topRight:    const Radius.circular(18),
//             bottomLeft:  Radius.circular(isUser ? 18 : 4),
//             bottomRight: Radius.circular(isUser ? 4 : 18),
//           ),
//           boxShadow: [
//             BoxShadow(
//               color: Colors.black.withOpacity(0.05),
//               blurRadius: 4,
//               offset: const Offset(0, 2),
//             ),
//           ],
//         ),
//         child: msg.text.isEmpty
//             ? _buildTypingDots()
//             : SelectableText(
//           msg.text,
//           style: TextStyle(
//             fontSize: 14,
//             height: 1.55,
//             color: isUser
//                 ? Colors.white
//                 : isErr
//                 ? Colors.red.shade700
//                 : const Color(0xFF1A1A1A),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildTypingDots() {
//     return Row(mainAxisSize: MainAxisSize.min, children: [
//       for (int i = 0; i < 3; i++) ...[
//         Container(
//           width: 7, height: 7,
//           decoration: BoxDecoration(
//               color: Colors.grey.shade300, shape: BoxShape.circle),
//         ),
//         if (i < 2) const SizedBox(width: 4),
//       ],
//     ]);
//   }
//
//   Widget _buildInputBar() {
//     final canSend = _modelLoaded && !_generating;
//     return Container(
//       color: Colors.white,
//       padding: EdgeInsets.only(
//         left: 12, right: 8, top: 10,
//         bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 10 : 24,
//       ),
//       child: SafeArea(
//         top: false,
//         child: Row(children: [
//           // ── text field ────────────────────────────────────────────────
//           Expanded(
//             child: Container(
//               decoration: BoxDecoration(
//                 color: const Color(0xFFF2F2ED),
//                 borderRadius: BorderRadius.circular(24),
//                 border: Border.all(color: Colors.grey.shade200),
//               ),
//               child: TextField(
//                 controller:      _inputCtrl,
//                 enabled:          canSend,
//                 maxLines:         5,
//                 minLines:         1,
//                 textInputAction:  TextInputAction.send,
//                 onSubmitted:      (_) => _send(),
//                 style: const TextStyle(fontSize: 14),
//                 decoration: InputDecoration(
//                   hintText: _modelLoaded
//                       ? (_generating ? 'Generating…' : 'Message Gemma…')
//                       : 'Loading model…',
//                   hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
//                   border: InputBorder.none,
//                   contentPadding:
//                   const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
//                 ),
//               ),
//             ),
//           ),
//           const SizedBox(width: 8),
//           // ── send button ───────────────────────────────────────────────
//           AnimatedContainer(
//             duration: const Duration(milliseconds: 150),
//             decoration: BoxDecoration(
//               color: canSend
//                   ? const Color(0xFF2D6A4F)
//                   : Colors.grey.shade200,
//               shape: BoxShape.circle,
//             ),
//             child: IconButton(
//               onPressed: canSend ? _send : null,
//               icon: Icon(
//                 _generating
//                     ? Icons.stop_rounded
//                     : Icons.arrow_upward_rounded,
//                 color: canSend ? Colors.white : Colors.grey.shade400,
//                 size: 22,
//               ),
//             ),
//           ),
//         ]),
//       ),
//     );
//   }
// }
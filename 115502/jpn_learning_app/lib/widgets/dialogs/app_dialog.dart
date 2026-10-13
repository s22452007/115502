import 'package:flutter/material.dart';
import 'package:jpn_learning_app/utils/constants.dart';

/// 全 App 統一的彈窗外觀。
///
/// 規格：
/// - 圓角 20、白底、無陰影感的扁平樣式
/// - 標題：主色粗體 18（可用 [titleColor] 換成紅色等）
/// - 內文：14、行高 1.5、深灰
/// - 按鈕列：左「取消」淡灰外框（占 1）＋右主按鈕實心（占 2），高 46、圓角 12；
///   只有一顆按鈕時主按鈕占滿整列
///
/// 一般情況直接用靜態方法：
///   `AppDialog.confirm(...)`（確認／取消，回傳 bool）
///   `AppDialog.message(...)`（只有一顆「知道了」）
///   `AppDialog.input(...)`（單一文字輸入框，回傳字串或 null）
/// 內容比較複雜的（表單、列表、獎勵畫面）就自己組 `AppDialog(...)`，
/// 需要完全自訂按鈕列時給 [actions]。
class AppDialog extends StatelessWidget {
  const AppDialog({
    super.key,
    this.title,
    this.titleColor,
    this.titleTrailing,
    this.header,
    this.content,
    this.cancelText,
    this.onCancel,
    this.confirmText,
    this.onConfirm,
    this.confirmColor,
    this.confirmLoading = false,
    this.actions,
    this.accent,
    this.centered = false,
    this.scrollable = true,
  });

  /// 標題文字；null 就不顯示標題列
  final String? title;

  /// 標題顏色，預設 [accent]（主色）；刪除類的可給紅色
  final Color? titleColor;

  /// 標題列右側的小元件（例如「* 必填」）
  final Widget? titleTrailing;

  /// 標題上方的元件（例如獎勵用的大圖示），會置中
  final Widget? header;

  final Widget? content;

  /// 取消鈕文字；null 就沒有取消鈕
  final String? cancelText;

  /// 取消鈕按下；null 就 `Navigator.pop(context)`
  final VoidCallback? onCancel;

  /// 主按鈕文字；null 就沒有主按鈕
  final String? confirmText;

  /// 主按鈕按下；給 null 且有 [confirmText] 時按鈕是停用狀態
  final VoidCallback? onConfirm;

  /// 主按鈕底色，預設 [accent]；刪除類的可給紅色
  final Color? confirmColor;

  /// 主按鈕顯示轉圈並停用（送出中）
  final bool confirmLoading;

  /// 完全自訂按鈕列（覆蓋 cancel／confirm 設定）
  final List<Widget>? actions;

  /// 主題色，預設 [AppColors.primary]；教育版頁面可傳藍色
  final Color? accent;

  /// 標題與內容置中（獎勵、成功提示用）
  final bool centered;

  /// 內容是否包在可捲動區（內容本身有 ListView 時設 false）
  final bool scrollable;

  static const BorderRadius radius = BorderRadius.all(Radius.circular(20));
  static const double buttonHeight = 46;
  static const double buttonRadius = 12;

  /// 內文預設字體：給自組 content 的人沿用
  static const TextStyle bodyStyle = TextStyle(
    fontSize: 14,
    height: 1.5,
    color: AppColors.textDark,
  );

  Color get _accent => accent ?? AppColors.primary;

  @override
  Widget build(BuildContext context) {
    final hasTitle = title != null || header != null;
    final titleWidget = hasTitle
        ? Column(
            crossAxisAlignment: centered
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (header != null) ...[
                Center(child: header),
                if (title != null) const SizedBox(height: 14),
              ],
              if (title != null)
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title!,
                        textAlign: centered
                            ? TextAlign.center
                            : TextAlign.start,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: titleColor ?? _accent,
                        ),
                      ),
                    ),
                    ?titleTrailing,
                  ],
                ),
            ],
          )
        : null;

    Widget? body = content;
    if (body != null) {
      body = DefaultTextStyle.merge(
        style: bodyStyle,
        textAlign: centered ? TextAlign.center : null,
        child: body,
      );
      if (scrollable) body = SingleChildScrollView(child: body);
    }

    final actionRow = actions ?? _defaultActions(context);

    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: radius),
      titlePadding: const EdgeInsets.fromLTRB(24, 22, 24, 0),
      contentPadding: EdgeInsets.fromLTRB(24, hasTitle ? 12 : 22, 24, 0),
      actionsPadding: EdgeInsets.fromLTRB(
        24,
        actionRow.isEmpty ? 0 : 20,
        24,
        actionRow.isEmpty ? 22 : 20,
      ),
      title: titleWidget,
      content: body,
      actions: actionRow,
    );
  }

  List<Widget> _defaultActions(BuildContext context) {
    final buttons = <Widget>[];
    if (cancelText != null) {
      buttons.add(
        Expanded(
          child: cancelButton(
            context,
            text: cancelText!,
            onPressed: onCancel,
            enabled: !confirmLoading,
          ),
        ),
      );
    }
    if (confirmText != null) {
      if (buttons.isNotEmpty) buttons.add(const SizedBox(width: 10));
      buttons.add(
        Expanded(
          flex: cancelText != null ? 2 : 1,
          child: primaryButton(
            text: confirmText!,
            onPressed: onConfirm,
            color: confirmColor ?? _accent,
            loading: confirmLoading,
          ),
        ),
      );
    }
    if (buttons.isEmpty) return const [];
    return [Row(children: buttons)];
  }

  /// 淡灰外框的次要按鈕（取消、再想想）
  static Widget cancelButton(
    BuildContext context, {
    String text = '取消',
    VoidCallback? onPressed,
    bool enabled = true,
  }) {
    return OutlinedButton(
      onPressed: !enabled ? null : (onPressed ?? () => Navigator.pop(context)),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.grey.shade700,
        side: BorderSide(color: Colors.grey.shade300),
        minimumSize: const Size(0, buttonHeight),
        // 彈窗只有約 280 寬，取消鈕占 1/3，預設左右 24 會把字擠成直排
        padding: const EdgeInsets.symmetric(horizontal: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
        ),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          text,
          maxLines: 1,
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  /// 實心主按鈕（確定、送出、知道了）
  static Widget primaryButton({
    required String text,
    VoidCallback? onPressed,
    Color color = AppColors.primary,
    bool loading = false,
  }) {
    return ElevatedButton(
      onPressed: loading ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        disabledBackgroundColor: color.withValues(alpha: 0.45),
        foregroundColor: Colors.white,
        disabledForegroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(0, buttonHeight),
        padding: const EdgeInsets.symmetric(horizontal: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(buttonRadius),
        ),
      ),
      child: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                text,
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
    );
  }

  /// 確認／取消，回傳 true 表示按了主按鈕；關掉或取消都是 false
  static Future<bool> confirm(
    BuildContext context, {
    required String title,
    String? message,
    Widget? content,
    String confirmText = '確定',
    String cancelText = '取消',
    bool destructive = false,
    Color? accent,
    bool barrierDismissible = true,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (ctx) => AppDialog(
        title: title,
        accent: accent,
        titleColor: destructive ? Colors.redAccent : null,
        confirmColor: destructive ? Colors.redAccent : null,
        content: content ?? (message != null ? Text(message) : null),
        cancelText: cancelText,
        onCancel: () => Navigator.pop(ctx, false),
        confirmText: confirmText,
        onConfirm: () => Navigator.pop(ctx, true),
      ),
    );
    return result ?? false;
  }

  /// 只有一顆按鈕的提示
  static Future<void> message(
    BuildContext context, {
    required String title,
    String? message,
    Widget? content,
    String buttonText = '知道了',
    Color? accent,
    bool centered = false,
    Widget? header,
    bool destructive = false,
    bool barrierDismissible = true,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (ctx) => AppDialog(
        title: title,
        header: header,
        centered: centered,
        accent: accent,
        titleColor: destructive ? Colors.redAccent : null,
        confirmColor: destructive ? Colors.redAccent : null,
        content: content ?? (message != null ? Text(message) : null),
        confirmText: buttonText,
        onConfirm: () => Navigator.pop(ctx),
      ),
    );
  }

  /// 單一文字輸入框；按主按鈕回傳修剪後的字串，取消回傳 null。
  /// 空字串時主按鈕停用（[allowEmpty] 為 true 則可送出空字串）。
  static Future<String?> input(
    BuildContext context, {
    required String title,
    String? initialValue,
    String? labelText,
    String? hintText,
    String? helperText,
    String confirmText = '儲存',
    String cancelText = '取消',
    int? maxLength,
    int maxLines = 1,
    bool allowEmpty = false,
    Color? accent,
    bool barrierDismissible = true,
  }) {
    return showDialog<String>(
      context: context,
      barrierDismissible: barrierDismissible,
      builder: (ctx) => _InputDialog(
        title: title,
        initialValue: initialValue,
        labelText: labelText,
        hintText: hintText,
        helperText: helperText,
        confirmText: confirmText,
        cancelText: cancelText,
        maxLength: maxLength,
        maxLines: maxLines,
        allowEmpty: allowEmpty,
        accent: accent,
      ),
    );
  }

  /// 統一的輸入框外觀：淡灰底、圓角 12、聚焦時主色框
  static InputDecoration inputDecoration({
    String? hintText,
    String? labelText,
    String? helperText,
    String? errorText,
    Color accent = AppColors.primary,
    Widget? suffixIcon,
    String? counterText = '',
  }) {
    OutlineInputBorder border(Color color, [double width = 1]) =>
        OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: width),
        );
    return InputDecoration(
      hintText: hintText,
      labelText: labelText,
      helperText: helperText,
      helperMaxLines: 3,
      errorText: errorText,
      counterText: counterText,
      suffixIcon: suffixIcon,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      filled: true,
      fillColor: AppColors.lightBg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      enabledBorder: border(Colors.grey.shade300),
      focusedBorder: border(accent, 1.5),
      errorBorder: border(Colors.redAccent),
      focusedErrorBorder: border(Colors.redAccent, 1.5),
    );
  }
}

class _InputDialog extends StatefulWidget {
  const _InputDialog({
    required this.title,
    required this.initialValue,
    required this.labelText,
    required this.hintText,
    required this.helperText,
    required this.confirmText,
    required this.cancelText,
    required this.maxLength,
    required this.maxLines,
    required this.allowEmpty,
    required this.accent,
  });

  final String title;
  final String? initialValue;
  final String? labelText;
  final String? hintText;
  final String? helperText;
  final String confirmText;
  final String cancelText;
  final int? maxLength;
  final int maxLines;
  final bool allowEmpty;
  final Color? accent;

  @override
  State<_InputDialog> createState() => _InputDialogState();
}

class _InputDialogState extends State<_InputDialog> {
  late final TextEditingController _ctrl = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _ctrl.text.trim());

  @override
  Widget build(BuildContext context) {
    final canSubmit = widget.allowEmpty || _ctrl.text.trim().isNotEmpty;
    return AppDialog(
      title: widget.title,
      accent: widget.accent,
      content: TextField(
        controller: _ctrl,
        autofocus: true,
        maxLength: widget.maxLength,
        maxLines: widget.maxLines,
        cursorColor: widget.accent ?? AppColors.primary,
        textInputAction: widget.maxLines == 1
            ? TextInputAction.done
            : TextInputAction.newline,
        onChanged: (_) => setState(() {}),
        onSubmitted: (_) => canSubmit ? _submit() : null,
        decoration: AppDialog.inputDecoration(
          labelText: widget.labelText,
          hintText: widget.hintText,
          helperText: widget.helperText,
          accent: widget.accent ?? AppColors.primary,
        ),
      ),
      cancelText: widget.cancelText,
      onCancel: () => Navigator.pop(context),
      confirmText: widget.confirmText,
      onConfirm: canSubmit ? _submit : null,
    );
  }
}

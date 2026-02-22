import 'package:flutter/material.dart';

/// ─────────────────────────────────────────────────────────────────────────────
///  GameQuitHandler  — drop-in mixin for every game screen
/// ─────────────────────────────────────────────────────────────────────────────
mixin GameQuitHandler<T extends StatefulWidget> on State<T> {
  bool _isQuitDialogShowing = false;

  Future<void> showQuitConfirmDialog(
      BuildContext context, {
        required VoidCallback onConfirm,
        VoidCallback? onCancel,
        String title = 'Quit Game?',
        String message = "Your current progress will be saved — you won't lose what you've earned!",
      }) async {
    if (_isQuitDialogShowing) return;
    _isQuitDialogShowing = true;

    final bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _QuitConfirmDialog(
        title: title,
        message: message,
      ),
    );

    _isQuitDialogShowing = false;

    if (confirmed == true && mounted) {
      onConfirm();
    } else if (onCancel != null && mounted) {
      onCancel();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  THEME CONSTANTS  (yellow-orange palette)
// ─────────────────────────────────────────────────────────────────────────────
class _QT {
  // Panel
  static const panelTop  = Color(0xFFBC30FF);
  static const panelBot  = Color(0xFFFA973D);
  static const accent    = Color(0xFFE8CDFF);

  // Keep Playing — gold
  static const goldTop   = Color(0xFFFFA600);
  static const goldBot   = Color(0xFFFF9F32);
  static const goldShadow= Color(0xFFFFB300);

  // Quit — warm brown with good contrast
  static const brownTop  = Color(0xd4354d);
  static const brownBot  = Color(0xe01433);
  static const brownShadow = Color(0xd4354d);

  static const white     = Colors.white;
  static const fontFamily = 'LilitaOne';

  static List<BoxShadow> glow(Color c, {double blur = 14, double spread = 3}) => [
    BoxShadow(color: c.withOpacity(0.75), blurRadius: blur,      spreadRadius: spread),
    BoxShadow(color: c.withOpacity(0.35), blurRadius: blur * 2,  spreadRadius: spread * 0.4),
  ];
}

// ─────────────────────────────────────────────────────────────────────────────
//  DIALOG
// ─────────────────────────────────────────────────────────────────────────────
class _QuitConfirmDialog extends StatelessWidget {
  final String title;
  final String message;

  const _QuitConfirmDialog({
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    // shortestSide is 720 on 1520×720 and 1080 on 1080×2400
    final ref = size.shortestSide;

    // All sizes relative to shortestSide — keeps proportions on both devices
    final imgSize  = ref * 0.22;   // icon circle
    final titleSz  = ref * 0.052;
    final msgSz    = ref * 0.034;
    final btnFont  = ref * 0.038;  // smaller so text never overflows
    final btnVPad  = ref * 0.032;
    final pad      = ref * 0.050;
    final radius   = ref * 0.068;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      // Horizontal inset keeps dialog from touching screen edges on any device
      insetPadding: EdgeInsets.symmetric(horizontal: size.width * 0.07),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end:   Alignment.bottomRight,
            colors: [_QT.panelTop, _QT.panelBot],
          ),
          border: Border.all(color: _QT.accent.withOpacity(0.75), width: 2.5),
          boxShadow: [
            ..._QT.glow(_QT.accent, blur: 30, spread: 4),
            const BoxShadow(
                color: Color(0xCC000000), blurRadius: 40, offset: Offset(0, 16)),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: Stack(
            children: [
              // Top gloss sheen
              Positioned(
                top: 0, left: 0, right: 0, height: 56,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end:   Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(0.08),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),

              Padding(
                padding: EdgeInsets.all(pad),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _CryingIcon(size: imgSize),
                    SizedBox(height: ref * 0.026),

                    _TitleText(title: title, fontSize: titleSz),
                    SizedBox(height: ref * 0.018),

                    _MessageText(message: message, fontSize: msgSz),
                    SizedBox(height: ref * 0.028),

                    _StarDivider(ref: ref),
                    SizedBox(height: ref * 0.028),

                    // Buttons — Expanded so they fill equally and never overflow
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(
                            child: _ArcadeDialogButton(
                              label:    'Keep Playing',
                              icon:     Icons.play_arrow_rounded,
                              top:      _QT.goldTop,
                              bottom:   _QT.goldBot,
                              shadow:   _QT.goldShadow,
                              vPad:     btnVPad,
                              fontSize: btnFont,
                              onTap: () => Navigator.of(context).pop(false),
                            ),
                          ),
                          SizedBox(width: ref * 0.025),
                          Expanded(
                            child: _ArcadeDialogButton(
                              label:    'Quit',
                              icon:     Icons.flag_rounded,
                              top:      _QT.brownTop,
                              bottom:   _QT.brownBot,
                              shadow:   _QT.brownShadow,
                              vPad:     btnVPad,
                              fontSize: btnFont,
                              onTap: () => Navigator.of(context).pop(true),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  SUB-WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _CryingIcon extends StatelessWidget {
  final double size;
  const _CryingIcon({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width:  size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [Color(0xFF5195CC), Color(0xFF86E7FF)],
        ),
        border: Border.all(color: _QT.accent.withOpacity(0.8), width: 2.5),
        boxShadow: _QT.glow(_QT.accent, blur: 22, spread: 2),
      ),
      child: ClipOval(
        child: Padding(
          padding: EdgeInsets.all(size * 0.10),
          child: Image.asset(
            'assets/images/pngs/crying.png',
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Icon(
              Icons.sentiment_very_dissatisfied_rounded,
              color: _QT.accent,
              size: size * 0.55,
            ),
          ),
        ),
      ),
    );
  }
}

class _TitleText extends StatelessWidget {
  final String title;
  final double fontSize;
  const _TitleText({required this.title, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily:    _QT.fontFamily,
        fontSize:      fontSize,
        fontWeight:    FontWeight.w900,
        color:         _QT.white,
        letterSpacing: 1.4,
        shadows: [
          Shadow(color: _QT.accent.withOpacity(0.8), blurRadius: 10),
          const Shadow(
              color: Color(0x99000000), blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
    );
  }
}

class _MessageText extends StatelessWidget {
  final String message;
  final double fontSize;
  const _MessageText({required this.message, required this.fontSize});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color:  Colors.white.withOpacity(0.07),
        border: Border.all(
            color: _QT.accent.withOpacity(0.25), width: 1),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: TextStyle(
          fontFamily: _QT.fontFamily,
          fontSize:   fontSize,
          color:      Colors.white.withOpacity(0.80),
          height:     1.4,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _StarDivider extends StatelessWidget {
  final double ref;
  const _StarDivider({required this.ref});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(5, (i) {
        final isCenter = i == 2;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: ref * 0.007),
          child: Icon(
            isCenter ? Icons.star_rounded : Icons.star_outline_rounded,
            color: isCenter
                ? const Color(0xFFFFD700)
                : Colors.white.withOpacity(0.28),
            size: isCenter ? ref * 0.042 : ref * 0.028,
            shadows: isCenter
                ? [const Shadow(color: Color(0xFFFFD700), blurRadius: 8)]
                : null,
          ),
        );
      }),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  ARCADE BUTTON
// ─────────────────────────────────────────────────────────────────────────────
class _ArcadeDialogButton extends StatefulWidget {
  final String   label;
  final IconData icon;
  final Color    top, bottom, shadow;
  final double   vPad, fontSize;
  final VoidCallback onTap;

  const _ArcadeDialogButton({
    required this.label,   required this.icon,
    required this.top,     required this.bottom,  required this.shadow,
    required this.vPad,    required this.fontSize,
    required this.onTap,
  });

  @override
  State<_ArcadeDialogButton> createState() => _ArcadeDialogButtonState();
}

class _ArcadeDialogButtonState extends State<_ArcadeDialogButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown:   (_) => setState(() => _pressed = true),
      onTapUp:     (_) { setState(() => _pressed = false); widget.onTap(); },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale:    _pressed ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 80),
        child: Container(
          padding: EdgeInsets.symmetric(vertical: widget.vPad),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(36),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end:   Alignment.bottomCenter,
              colors: [widget.top, widget.bottom],
            ),
            boxShadow: [
              BoxShadow(
                color:      widget.bottom.withOpacity(0.9),
                blurRadius: 0, spreadRadius: 0,
                offset:     Offset(0, _pressed ? 1 : 4),
              ),
              BoxShadow(
                  color: widget.shadow.withOpacity(0.55),
                  blurRadius: 14, spreadRadius: 1),
              BoxShadow(
                  color: widget.shadow.withOpacity(0.22), blurRadius: 26),
            ],
            border: Border.all(
                color: Colors.white.withOpacity(0.25), width: 1.5),
          ),
          child: Stack(alignment: Alignment.center, children: [
            // Gloss highlight
            Positioned(
              top: 0, left: 0, right: 0, bottom: 10,
              child: ClipRRect(
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(36)),
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end:   Alignment.bottomCenter,
                      colors: [
                        Colors.white.withOpacity(0.30),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // FittedBox prevents text overflow on narrow buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(widget.icon,
                        color: Colors.white,
                        size: widget.fontSize + 4,
                        shadows: [
                          Shadow(
                              color: Colors.black.withOpacity(0.45),
                              blurRadius: 4),
                        ]),
                    const SizedBox(width: 6),
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontFamily:    _QT.fontFamily,
                        color:         Colors.white,
                        fontSize:      widget.fontSize,
                        fontWeight:    FontWeight.w900,
                        letterSpacing: 0.8,
                        shadows: const [
                          Shadow(
                              color: Color(0x99000000),
                              blurRadius: 4,
                              offset: Offset(0, 2)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}
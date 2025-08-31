import 'package:flutter/material.dart';

// Page transition animations
class FadePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  
  FadePageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 300),
        );
}

class SlidePageRoute<T> extends PageRouteBuilder<T> {
  final Widget page;
  final SlideDirection direction;
  
  SlidePageRoute({
    required this.page,
    this.direction = SlideDirection.right,
  }) : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            Offset begin;
            switch (direction) {
              case SlideDirection.right:
                begin = const Offset(1.0, 0.0);
                break;
              case SlideDirection.left:
                begin = const Offset(-1.0, 0.0);
                break;
              case SlideDirection.up:
                begin = const Offset(0.0, 1.0);
                break;
              case SlideDirection.down:
                begin = const Offset(0.0, -1.0);
                break;
            }
            
            const end = Offset.zero;
            const curve = Curves.easeInOutCubic;
            
            var tween = Tween(begin: begin, end: end).chain(
              CurveTween(curve: curve),
            );
            
            return SlideTransition(
              position: animation.drive(tween),
              child: child,
            );
          },
          transitionDuration: const Duration(milliseconds: 350),
        );
}

enum SlideDirection { left, right, up, down }

// Animated widgets
class AnimatedListItem extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration delay;
  
  const AnimatedListItem({
    super.key,
    required this.child,
    required this.index,
    this.delay = const Duration(milliseconds: 50),
  });
  
  @override
  State<AnimatedListItem> createState() => _AnimatedListItemState();
}

class _AnimatedListItemState extends State<AnimatedListItem>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _slide;
  
  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    
    _opacity = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
    
    _slide = Tween<Offset>(
      begin: const Offset(0.0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    
    // Start animation with delay based on index
    Future.delayed(widget.delay * widget.index, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(
        position: _slide,
        child: widget.child,
      ),
    );
  }
}

// Pulse animation for recording/playing indicators
class PulseAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double minScale;
  final double maxScale;
  
  const PulseAnimation({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 1500),
    this.minScale = 0.95,
    this.maxScale = 1.05,
  });
  
  @override
  State<PulseAnimation> createState() => _PulseAnimationState();
}

class _PulseAnimationState extends State<PulseAnimation>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  
  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat(reverse: true);
    
    _scale = Tween<double>(
      begin: widget.minScale,
      end: widget.maxScale,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _scale,
      builder: (context, child) => Transform.scale(
        scale: _scale.value,
        child: widget.child,
      ),
    );
  }
}

// Shimmer loading effect
class ShimmerLoading extends StatefulWidget {
  final Widget child;
  final bool isLoading;
  
  const ShimmerLoading({
    super.key,
    required this.child,
    required this.isLoading,
  });
  
  @override
  State<ShimmerLoading> createState() => _ShimmerLoadingState();
}

class _ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  
  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    
    _animation = Tween<double>(
      begin: -1.0,
      end: 2.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.linear,
    ));
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    if (!widget.isLoading) {
      return widget.child;
    }
    
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return ShaderMask(
          shaderCallback: (bounds) {
            return LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Theme.of(context).colorScheme.surface,
                Theme.of(context).colorScheme.surface.withOpacity(0.5),
                Theme.of(context).colorScheme.surface,
              ],
              stops: [
                _animation.value - 0.3,
                _animation.value,
                _animation.value + 0.3,
              ],
              transform: const GradientRotation(0.5),
            ).createShader(bounds);
          },
          child: widget.child,
        );
      },
    );
  }
}

// Animated progress indicator
class AnimatedProgressBar extends StatelessWidget {
  final double progress;
  final Duration duration;
  final Color? backgroundColor;
  final Color? valueColor;
  final double height;
  
  const AnimatedProgressBar({
    super.key,
    required this.progress,
    this.duration = const Duration(milliseconds: 500),
    this.backgroundColor,
    this.valueColor,
    this.height = 4.0,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: backgroundColor ?? 
               Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(height / 2),
      ),
      child: AnimatedFractionallySizedBox(
        duration: duration,
        curve: Curves.easeOutCubic,
        widthFactor: progress.clamp(0.0, 1.0),
        alignment: Alignment.centerLeft,
        child: Container(
          decoration: BoxDecoration(
            color: valueColor ?? Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(height / 2),
          ),
        ),
      ),
    );
  }
}

// Animated icon button
class AnimatedIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final Color? color;
  
  const AnimatedIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.size = 24.0,
    this.color,
  });
  
  @override
  State<AnimatedIconButton> createState() => _AnimatedIconButtonState();
}

class _AnimatedIconButtonState extends State<AnimatedIconButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;
  
  @override
  void initState() {
    super.initState();
    
    _controller = AnimationController(
      duration: const Duration(milliseconds: 150),
      vsync: this,
    );
    
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.85,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    ));
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  void _handleTap() {
    _controller.forward().then((_) {
      _controller.reverse();
      widget.onPressed();
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _handleTap,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) => Transform.scale(
          scale: _scale.value,
          child: Icon(
            widget.icon,
            size: widget.size,
            color: widget.color,
          ),
        ),
      ),
    );
  }
}

// Hero animation wrapper
class HeroWrapper extends StatelessWidget {
  final String tag;
  final Widget child;
  
  const HeroWrapper({
    super.key,
    required this.tag,
    required this.child,
  });
  
  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: tag,
      child: Material(
        type: MaterialType.transparency,
        child: child,
      ),
    );
  }
}

// Animated text switcher
class AnimatedTextSwitcher extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final Duration duration;
  
  const AnimatedTextSwitcher({
    super.key,
    required this.text,
    this.style,
    this.duration = const Duration(milliseconds: 300),
  });
  
  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: duration,
      transitionBuilder: (child, animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.0, 0.5),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: Text(
        text,
        key: ValueKey<String>(text),
        style: style,
      ),
    );
  }
}
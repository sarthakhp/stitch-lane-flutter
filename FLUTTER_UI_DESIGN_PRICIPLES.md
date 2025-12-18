# Flutter UI Design Principles

> **For AI Assistants**: When implementing ANY new feature, screen, or UI component in this Flutter project, you MUST follow these principles. Treat this as a mandatory checklist. If the user asks for a feature without specifying design details, proactively apply these principles to create responsive, attractive, and polished UIs.

Creating a Flutter app that is both responsive (works on all screen sizes) and attractive (visually polished) requires balancing technical layout logic with aesthetic design systems.
Here are the core principles to follow, divided into layout mechanics and visual aesthetics.

## 🎯 AI Implementation Mandate

When implementing features, you must:
1. **Always ask yourself**: "Does this work on phone, tablet, and desktop?"
2. **Never hardcode**: Avoid fixed pixel values; use constraints and ratios
3. **Think motion-first**: Every state change should animate
4. **Maintain consistency**: Follow existing patterns in the codebase
5. **Accessibility matters**: Ensure touch targets are ≥48px, text is readable, colors have sufficient contrast

## I. Principles of Responsiveness (The Mechanics)

Responsive design is not just about scaling elements; it is about adapting the interface to the available space.

### 1. Adaptive Navigation

Your navigation should change based on the device form factor. Do not force a "Bottom Navigation Bar" on a desktop screen.

* **Mobile**: Use NavigationBar (Bottom).
* **Tablet/Desktop**: Use NavigationRail (Side) or NavigationDrawer.
* **Tool**: Use the `flutter_adaptive_scaffold` package. It automates switching between these modes based on breakpoints.

**Tip**: Avoid defining "mobile" vs "tablet" by device type (e.g., `Platform.isAndroid`). Define them by screen width (e.g., < 600px is compact, > 600px is medium).

### 2. Constraint-Based Layouts

Avoid hardcoding pixel values (e.g., `width: 300`). Instead, "think in ratios."

* **Flexibility**: Use `Row` and `Column` combined with `Expanded` and `Flexible` widgets to let content fill available space.
* **Ratios**: Use `AspectRatio` to keep images or cards consistent regardless of screen width.
* **Fractions**: Use `FractionallySizedBox` to size elements relative to their parent (e.g., a button that is always 80% of the modal width).

### 3. Split-View Pattern (List-Detail)

On large screens, avoid stretching a single list of items across the entire width.

* **Phone**: Show the List. When an item is tapped, navigate to a new Detail screen.
* **Tablet**: Show the List on the left (30% width) and the Detail view on the right (70% width) simultaneously.

## II. Principles of Attractiveness (The Aesthetics)

For a modern, attractive look in 2025, stick to Material 3 (Material You) principles, which are now the default in Flutter.

### 1. Leverage "Dynamic Color"

Don't pick random hex codes. Use a seeded ColorScheme.

* Pass a single `seedColor` to your `ThemeData`. Flutter will generate a mathematically accessible palette of 30+ matching tones (Primary, Secondary, Tertiary, Surface, Error).
* **Why?** This ensures your UI always looks harmonious and professionally color-graded.

```dart
ThemeData(
  useMaterial3: true,
  colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
)
```

### 2. Hierarchy via Elevation and Tone

In Material 3, shadows are softer. Use Surface Tones to separate layers instead of heavy drop shadows.

* **Level 0 (Background)**: Pure color.
* **Level 1 (Cards)**: Slight tint of the primary color.
* **Level 2 (Dialogs)**: Stronger tint.
* **Principle**: The more "important" or "floating" an element is, the more colored tint it should have.

### 3. Motion is Mandatory

Static UIs feel "cheap." Motion provides polish and context.

* **Hero Animations**: Use `Hero` widgets to make an image "fly" from a list to a detail view.
* **Implicit Animations**: Never use a raw `Container` if properties change. Use `AnimatedContainer` or `AnimatedOpacity`. These automatically animate changes (like a button growing when pressed) without complex code.

### 4. The 8-Point Grid System

To make your app look "clean," spacing must be consistent.

* Use multiples of 8 (8, 16, 24, 32, 48) for all padding and margins.
* Avoid arbitrary numbers like `padding: 13.0`. The human eye notices the irregularity.

## III. Essential Toolkit for Implementation

| Tool/Widget | Purpose |
|-------------|---------|
| `LayoutBuilder` | The fundamental widget for responsiveness. It gives you the constraints of the parent so you can decide what to render. |
| `Wrap` | Use this instead of `Row` for tags or buttons. It automatically moves items to the next line if the screen is too narrow. |
| `FittedBox` | Forces text/content to scale down if the screen is too small, preventing "overflow" errors. |

## IV. Summary Checklist for your App

1. [ ] **Enable M3**: Set `useMaterial3: true` in `ThemeData`.
2. [ ] **Check Breakpoints**: Does layout switch from `Column` to `Row` on widths > 600px?
3. [ ] **Dark Mode**: Did you test your UI in Dark Mode? (Seeded ColorSchemes handle this automatically).
4. [ ] **Input Type**: Does it work with a finger (large touch targets) and a mouse (hover effects)?

---

## V. Advanced Principles for Dynamic & Attractive UIs

### 5. Smart Loading States
* ❌ BAD: `isLoading ? CircularProgressIndicator() : Content()`
* ✅ GOOD: Use shimmer/skeleton screens that match content layout
* **Why**: Users perceive skeleton screens as 30% faster

### 6. Contextual Empty States
* Include: Illustration/icon + helpful message + action button
* ❌ BAD: "No items found"
* ✅ GOOD: "Your cart is empty. Start shopping to add items!"

### 7. Micro-interactions
* Button press → scale down slightly (`AnimatedScale`)
* Success → checkmark animation
* Form errors → shake animation
* **Rule**: Every state change should animate

### 8. Typography Hierarchy
* **Always use**: `Theme.of(context).textTheme.bodyLarge` (never hardcode sizes)
* **Rule**: 1 display/headline per screen, 2-3 body styles max
* **Readability**: Body text should have `height: 1.5`

### 9. Consistent Spacing System
```dart
class AppSpacing {
  static const double xs = 4.0;   // Tight spacing
  static const double sm = 8.0;   // Small gaps
  static const double md = 16.0;  // Default padding
  static const double lg = 24.0;  // Section spacing
  static const double xl = 32.0;  // Large gaps
  static const double xxl = 48.0; // Screen margins
}
```

### 10. Smart Image Handling
* **Always use**: `cached_network_image` package
* **Aspect Ratios**: 16:9 for banners, 1:1 for avatars
* **Error States**: Show fallback icon, not broken image

### 11. Gesture-Friendly Design
* **Touch Targets**: Minimum 48x48px (Material guideline)
* **Primary Actions**: Bottom of screen (thumb zone)
* **Haptic Feedback**: `HapticFeedback.lightImpact()` on important actions

### 12. Smooth Page Transitions
* Use `Hero` widget for shared elements
* Use `PageRouteBuilder` for custom transitions (fade, slide, scale)
* ❌ BAD: Abrupt navigation
* ✅ GOOD: Smooth, contextual transitions

### 13. Form Design Excellence
* Use `OutlinedBorder` (M3 default) with proper labels
* Show errors inline, not in dialogs
* Auto-focus first field, use `TextInputAction.next`
* Disable submit button while loading

### 14. Performance-Conscious Rendering
* Use `const` constructors wherever possible
* Use `ListView.builder`, never `ListView(children: [...])`
* Use `cacheHeight`/`cacheWidth` for images
* Avoid `Opacity` widget (use `AnimatedOpacity` instead)

---

## VI. AI Decision-Making Framework

### When implementing a feature, ask:
1. **Context**: What screen size? Primary or secondary action?
2. **Pattern**: List? Form? Detail view? Settings?
3. **Principles**: Responsive? Themed? Animated? States handled?
4. **Polish**: Micro-interactions? Dark mode? Multiple screen sizes?

### Common Patterns Quick Reference

**Responsive Grid**:
```dart
LayoutBuilder(
  builder: (context, constraints) {
    final cols = constraints.maxWidth > 600 ? 3 : 2;
    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: cols,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
      ),
      itemBuilder: (context, index) => YourCard(),
    );
  },
)
```

**Adaptive Layout**:
```dart
LayoutBuilder(
  builder: (context, constraints) {
    if (constraints.maxWidth > 840) return Row([Sidebar(), Content()]);
    if (constraints.maxWidth > 600) return Scaffold(drawer: Sidebar(), body: Content());
    return Content(); // Mobile
  },
)
```

---

## VII. Final AI Checklist

**Before submitting ANY UI implementation, verify:**

### Responsiveness
1. ✅ Works on mobile (< 600px), tablet (600-840px), desktop (> 840px)
2. ✅ Works in dark mode

### States
3. ✅ Has loading state (shimmer/skeleton)
4. ✅ Has error state (friendly message + action)
5. ✅ Has empty state (illustration + message + action)

### Theming
6. ✅ Uses theme colors (no hardcoded hex)
7. ✅ Uses theme text styles (no hardcoded sizes)
8. ✅ Follows 8-point spacing grid

### Polish
9. ✅ Has appropriate animations (state changes, transitions)
10. ✅ Touch targets are ≥48px
11. ✅ Uses `const` where possible
12. ✅ Follows existing code patterns in the project

**If you cannot verify all items, explicitly state which and why.**

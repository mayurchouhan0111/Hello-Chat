# SVGA Animation Placement & Dynamic Avatar Problem

This document explains the technical details of the SVGA placement issue in the dynamic rocket completion overlays, why standard SVGA dynamic replacement is not possible with the current assets, and how it is resolved.

---

## 1. How SVGA Dynamic Avatars Work (Standard Approach)

SVGA is a vector-based animation format that allows developers to render high-performance, scale-independent animations on mobile screens. 

### Placeholder Sprites
When exporting an animation from Adobe After Effects (via the SVGA exporter plugin), animators can designate specific layers or shapes as **placeholder keys** (e.g., naming a circle layer `"avatar_anchor"`).

During runtime:
1. The client-side code loads the SVGA file.
2. The code searches the animation timeline for the designated key (e.g., `"avatar_anchor"`).
3. The code programmatically replaces that specific vector element with a downloaded network image (the user's profile avatar).
4. The SVGA player draws the profile picture directly inside the animation, moving, scaling, and rotating it perfectly in sync with the rocket.

---

## 2. The Problem with hello_chat Rocket SVGA Assets

For the rocket completion animations (e.g., `1.4.svga`, `2.4.svga`, `3.4.svga`, etc.), the animator did not configure any placeholder sprite keys or coordinate markers during the After Effects export.

### Structural Analysis:
* **Sequential Image Frames**: The animation does not contain distinct, queryable vector path groups for the windows or cockpit of the rocket. Instead, the animation is rendered as a sequence of full-screen frames (e.g., `750x1624` or `375x812` pixels) containing drawing operations for the entire rocket structure, smoke, and particle blasts.
* **No Vector Anchors**: There are no labeled shape paths (such as `"avatar_position"` or `"contributor_avatar"`) inside the vector timeline.
* **Zero Metadata**: Because there is no metadata or anchor shape, the SVGA player cannot:
  1. Replace any layer dynamically with the avatar image.
  2. Tell the Flutter code what the $(x, y)$ coordinates of the rocket window are on frame 40, 50, or 60.

---

## 3. The Programmatic Fallback Solution

Since the SVGA files lack the internal placeholder keys required to automatically bind the contributor's avatar, we implemented a custom layout fallback:

1. **Stacking Layer Overlay**:
   We wrap the SVGA player inside a Flutter `Stack` widget and place a custom Flutter widget (containing the profile image and username banner) on top.

2. **Calculated Horizontal Centering**:
   We position the contributor's card programmatically in the layout:
   ```dart
   Positioned(
     top: screenHeight * 0.28, // Top offset below title text
     left: 0,
     right: 0,
     child: Center(
       child: ContributorCardWidget(
         avatarUrl: topContributor.avatar,
         name: topContributor.name,
       ),
     ),
   )
   ```

3. **Smooth Entrance & Synchronization**:
   We synchronize the appearance of the overlay card with the rocket animation using delayed timers matching the blast timeline. This displays the avatar clearly, bypassing the limitations of the SVGA files.

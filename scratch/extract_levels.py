import os
from PIL import Image

def extract_level_badges(input_path, output_folder):
    if not os.path.exists(output_folder):
        os.makedirs(output_folder)

    # Load and convert
    img = Image.open(input_path).convert("RGBA")
    width, height = img.size
    
    # Sample background color from top-left
    bg_color = img.getpixel((0, 0))
    print(f"Sampling background color: {bg_color}")

    def get_distance(p1, p2):
        return ((p1[0]-p2[0])**2 + (p1[1]-p2[1])**2 + (p1[2]-p2[2])**2)**0.5

    # Create mask: remove background based on color distance
    print("Generating mask for the entire sheet...")
    pixels = img.load()
    mask = Image.new("L", (width, height), 0)
    mask_pixels = mask.load()
    
    for y in range(height):
        for x in range(width):
            if get_distance(pixels[x, y], bg_color) > 60: # Threshold for dark background
                mask_pixels[x, y] = 255

    # Find connected components (badges)
    visited = set()
    components = []

    print("Finding individual badges via connected components...")
    for x in range(width):
        for y in range(height):
            if mask_pixels[x, y] == 255 and (x, y) not in visited:
                # New component found
                component_pixels = []
                q = [(x, y)]
                visited.add((x, y))
                
                # BFS
                while q:
                    curr_x, curr_y = q.pop(0)
                    component_pixels.append((curr_x, curr_y))
                    
                    for dx, dy in [(-1,0), (1,0), (0,-1), (0,1), (-1,-1), (-1,1), (1,-1), (1,1)]:
                        nx, ny = curr_x + dx, curr_y + dy
                        if 0 <= nx < width and 0 <= ny < height:
                            if mask_pixels[nx, ny] == 255 and (nx, ny) not in visited:
                                visited.add((nx, ny))
                                q.append((nx, ny))
                
                # Only keep components of a reasonable size
                if len(component_pixels) > 500:
                    components.append(component_pixels)
                    print(f"Found badge component with {len(component_pixels)} pixels.")

    # Sort components by their horizontal center
    def get_center_x(comp):
        return sum(p[0] for p in comp) / len(comp)
    
    components.sort(key=get_center_x)

    # Save the 6 largest/most prominent components
    print(f"Total components found: {len(components)}. Extracting the top 6...")
    
    # If more than 6, filter by size (to avoid small noise/sparks)
    if len(components) > 6:
        components.sort(key=len, reverse=True)
        components = components[:6]
        components.sort(key=get_center_x) # Sort back to left-to-right order

    for i, comp in enumerate(components):
        # Create a transparent image for this component
        min_x = min(p[0] for p in comp)
        max_x = max(p[0] for p in comp)
        min_y = min(p[1] for p in comp)
        max_y = max(p[1] for p in comp)
        
        w, h = max_x - min_x + 1, max_y - min_y + 1
        badge_img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        badge_pixels = badge_img.load()
        
        for px, py in comp:
            badge_pixels[px - min_x, py - min_y] = pixels[px, py]
            
        filename = f"level_badge_{i}.png"
        badge_img.save(os.path.join(output_folder, filename), "PNG")
        print(f"Saved: {filename} ({w}x{h})")

if __name__ == "__main__":
    input_img = r"d:\UnHuman\Apps\Hello Chat\hellochat\assets\images\LEVEL.png"
    output_dir = r"d:\UnHuman\Apps\Hello Chat\hellochat\assets\images\levels"
    extract_level_badges(input_img, output_dir)

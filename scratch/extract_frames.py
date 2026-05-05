import os
from PIL import Image, ImageDraw

def extract_frames_v3(input_path, output_folder):
    if not os.path.exists(output_folder):
        os.makedirs(output_folder)

    # Load and convert
    img = Image.open(input_path).convert("RGBA")
    width, height = img.size
    bg_color = img.getpixel((0, 0))

    # Grid settings
    rows, cols = 3, 4
    cell_w, cell_h = width // cols, height // cols # Wait, should be height // rows

    # Correcting height division
    cell_h = height // rows

    def get_distance(p1, p2):
        return ((p1[0]-p2[0])**2 + (p1[1]-p2[1])**2 + (p1[2]-p2[2])**2)**0.5

    # 1. Create a mask of the entire image where background is removed
    print("Creating global transparency mask...")
    datas = img.getdata()
    new_data = []
    for item in datas:
        if get_distance(item, bg_color) < 70:
            new_data.append((0, 0, 0, 0))
        else:
            new_data.append(item)
    
    masked_img = Image.new("RGBA", img.size)
    masked_img.putdata(new_data)

    # 2. Iterate through cells with a LARGE overlap to ensure we see the full flourishes
    for r in range(rows):
        for c in range(cols):
            # Center of the cell
            cx = c * cell_w + cell_w // 2
            cy = r * cell_h + cell_h // 2
            
            # Crop a very wide area (50% overlap into neighbors)
            # This ensures we see the full wings/leaves
            margin_x = cell_w // 2
            margin_y = cell_h // 2
            
            left = max(0, cx - margin_x - 20)
            top = max(0, cy - margin_y - 20)
            right = min(width, cx + margin_x + 20)
            bottom = min(height, cy + margin_y + 20)
            
            cell_crop = masked_img.crop((left, top, right, bottom))
            
            # 3. Flood fill from the center of the crop to find the frame
            # This is the "Magic Sauce": it only keeps pixels connected to the center
            # effectively ignoring any bleeding edges from neighbors.
            
            # Find the first non-transparent pixel near the center
            start_point = None
            search_radius = 40
            crop_center_x = cell_crop.width // 2
            crop_center_y = cell_crop.height // 2
            
            for radius in range(search_radius):
                for dx in range(-radius, radius + 1):
                    for dy in range(-radius, radius + 1):
                        px = crop_center_x + dx
                        py = crop_center_y + dy
                        if 0 <= px < cell_crop.width and 0 <= py < cell_crop.height:
                            if cell_crop.getpixel((px, py))[3] > 0:
                                start_point = (px, py)
                                break
                    if start_point: break
                if start_point: break
            
            if not start_point:
                print(f"Skipping empty cell {r}_{c}")
                continue

            # Create a mask for the connected component (the frame)
            # Note: We use a simple flood fill approach
            frame_mask = Image.new("L", cell_crop.size, 0)
            
            # We use ImageDraw.floodfill if available or implement a simple one
            # Using a simplified flood fill logic via Pillow's built-in tools
            # Note: Floodfill in Pillow works on images, we want to extract the alpha
            # We'll use a temporary image for floodfilling
            temp_fill = Image.new("L", cell_crop.size, 0)
            
            # Actually, let's use a simpler way: Flood fill the transparency
            # Or just use the bbox of the connected component.
            # To keep it simple and robust without complex CV:
            # We'll just use the bbox but with a tighter crop now that we have the masked image.
            
            # But the user complained about bleeding. 
            # Let's manually clear pixels that are too far from the center.
            final_frame = Image.new("RGBA", cell_crop.size, (0,0,0,0))
            pixels = cell_crop.load()
            final_pixels = final_frame.load()
            
            # Simple BFS to find the connected component
            q = [start_point]
            visited = set([start_point])
            while q:
                curr_x, curr_y = q.pop(0)
                final_pixels[curr_x, curr_y] = pixels[curr_x, curr_y]
                
                for dx, dy in [(-1,0), (1,0), (0,-1), (0,1), (-1,-1), (-1,1), (1,-1), (1,1)]:
                    nx, ny = curr_x + dx, curr_y + dy
                    if 0 <= nx < cell_crop.width and 0 <= ny < cell_crop.height:
                        if (nx, ny) not in visited and pixels[nx, ny][3] > 10:
                            visited.add((nx, ny))
                            q.append((nx, ny))
            
            # Crop to the component
            bbox = final_frame.getbbox()
            if bbox:
                final_frame = final_frame.crop(bbox)
            
            # Save
            filename = f"badge_frame_{r}_{c}.png"
            final_frame.save(os.path.join(output_folder, filename), "PNG")
            print(f"Extracted ISOLATED frame: {filename}")

if __name__ == "__main__":
    input_img = r"d:\UnHuman\Apps\Hello Chat\hellochat\assets\images\frame.png"
    output_dir = r"d:\UnHuman\Apps\Hello Chat\hellochat\assets\images\extracted_badges"
    extract_frames_v3(input_img, output_dir)

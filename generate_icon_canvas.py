from PIL import Image, ImageDraw

def create_app_icon(filename="assets/icon/app_icon.png"):
    # Create a 1024x1024 image with a transparent background
    img = Image.new("RGBA", (1024, 1024), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # Base shape - Rounded Rectangle
    bg_color = (37, 99, 235, 255) # Primary Blue
    draw.rounded_rectangle([(64, 64), (960, 960)], radius=224, fill=bg_color)
    
    # Shield shape inside
    shield_color = (255, 255, 255, 255)
    # Just draw a simple polygon for the shield
    points = [(512, 200), (800, 300), (800, 600), (512, 850), (224, 600), (224, 300)]
    draw.polygon(points, fill=shield_color)
    
    # Inner checkmark / simple icon
    check_color = (37, 99, 235, 255)
    draw.line([(380, 500), (480, 620), (680, 380)], fill=check_color, width=64, joint="curve")

    img.save(filename)

create_app_icon()

from PIL import Image

def convert_to_grayscale(input_image_path, output_image_path):
    # Open the image file
    image = Image.open(input_image_path)

    # Convert the image to grayscale
    grayscale_image = image.convert("L")

    # Save the grayscale image
    grayscale_image.save(output_image_path)

if __name__ == "__main__":
    input_image_path = "input_image.jpg"  # Provide the path to your input image
    output_image_path = "output_grayscale_image.jpg"  # Provide the path where you want to save the output image

    convert_to_grayscale(input_image_path, output_image_path)


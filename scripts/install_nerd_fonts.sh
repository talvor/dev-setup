
#!/bin/bash

echo "Installing Nerd Fonts..."

# List of Nerd Fonts to install
fonts=(
    "Hack"
    "FiraCode"
    "SourceCodePro"
    "DejaVuSansMono"
    "UbuntuMono"
    "JetBrainsMono"
)

# Directory to install fonts
font_dir="$HOME/.local/share/fonts/NerdFonts"

# Create the fonts directory if it doesn't exist
mkdir -p "$font_dir"

# Download and install each font
for font in "${fonts[@]}"; do
    echo "Installing $font..."
    font_url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/${font}.zip"
    temp_dir=$(mktemp -d)

    # Download the font zip file
    curl -L -o "$temp_dir/${font}.zip" "$font_url"
    
    # Unzip the font
    unzip -q "$temp_dir/${font}.zip" -d "$temp_dir"

    # Move the fonts to the target directory
    find "$temp_dir" -name '*.ttf' -exec mv {} "$font_dir" \;

    # Clean up
    rm -rf "$temp_dir"
done

# Update the font cache
echo "Updating font cache..."
fc-cache -fv

echo "Nerd Fonts installation complete."

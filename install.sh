#!/bin/bash

# Function to check if a command exists
command_exists () {
    command -v "$1" &> /dev/null
}

# Function to execute a command and check for errors
execute_with_error_check () {
    "$@"
    if [ $? -ne 0 ]; then
        echo "Error occurred while executing: $*"
        return 1
    fi
}

# Update package list and upgrade all packages
echo "Updating system..."
execute_with_error_check sudo apt update && sudo apt upgrade -y || exit 1

# Check if Python 3 is installed
if command_exists python3; then
    echo "Python 3 is already installed."
else
    echo "Python 3 is not installed. Installing Python 3..."
    execute_with_error_check sudo apt install -y python3 python3-pip || exit 1
fi

# Ensure Python 3 is the default Python version
if command_exists python; then
    PYTHON_VERSION=$(python -V 2>&1 | awk '{print $2}')
    if [[ "$PYTHON_VERSION" == 3* ]]; then
        echo "Python default version is already Python 3."
    else
        echo "Setting Python 3 as the default Python version..."
        execute_with_error_check sudo update-alternatives --install /usr/bin/python python /usr/bin/python3 1 || exit 1
    fi
else
    echo "Setting Python 3 as the default Python version..."
    execute_with_error_check sudo update-alternatives --install /usr/bin/python python /usr/bin/python3 1 || exit 1
fi

# Check if Python 3 is set up correctly
PYTHON_VERSION=$(python -V 2>&1 | awk '{print $2}')
if [[ "$PYTHON_VERSION" == 3* ]]; then
    echo "Python 3 is correctly set up as the default version."
else
    echo "There was an issue setting Python 3 as the default version."
    exit 1
fi

# Install software-properties-common if not installed
echo "Installing dependencies..."
execute_with_error_check sudo apt install -y software-properties-common || exit 1

# Remove old FFmpeg PPA if it exists
echo "Removing old FFmpeg PPA if it exists..."
sudo add-apt-repository --remove ppa:savoury1/ffmpeg4 || true

# # Add a new FFmpeg PPA
# echo "Adding FFmpeg PPA..."
# execute_with_error_check sudo add-apt-repository -y ppa:jonathonf/ffmpeg-4 || exit 1

# Update package list after adding the new PPA
echo "Updating package list..."
execute_with_error_check sudo apt update || exit 1

# Install FFmpeg
echo "Installing FFmpeg..."
execute_with_error_check sudo apt install -y ffmpeg || exit 1

# Verify FFmpeg installation
echo "Verifying FFmpeg installation..."
ffmpeg -version || exit 1

echo "FFmpeg installation complete!"

# Check if virtualenv is installed, if not, install it
echo "Checking if virtualenv is installed..."
if ! command_exists virtualenv; then
    echo "virtualenv not found. Installing virtualenv..."
    execute_with_error_check sudo apt install -y python3-venv || exit 1
fi

# Check if the 'stream' virtual environment exists
if [ ! -d "stream" ]; then
    echo "Creating virtual environment 'stream'..."
    execute_with_error_check python3 -m venv stream || exit 1
else
    echo "Virtual environment 'stream' already exists."
fi

# Activate the 'stream' virtual environment
echo "Activating virtual environment 'stream'..."
source stream/bin/activate || exit 1

# Check if requirements.txt exists
if [ -f "requirements.txt" ]; then
    echo "Installing packages from requirements.txt..."
    execute_with_error_check pip install -r requirements.txt || exit 1
else
    echo "requirements.txt not found. Please ensure it is in the current directory."
fi

echo "Setup complete!"

# Ensure UFW is installed
if ! command_exists ufw; then
    echo "UFW is not installed. Installing UFW..."
    execute_with_error_check sudo apt install -y ufw || exit 1
else
    echo "UFW is already installed."
fi

# Check if .env file exists
if [ -f ".env" ]; then
    echo "Reading .env file..."
    
    # Use Python to extract the PORT from the .env file
    PORT=$(python3 -c 'import os; from dotenv import load_dotenv; load_dotenv(); print(os.getenv("PORT"))')
    
    if [ -z "$PORT" ]; then
        echo "No PORT value found in .env file."
    else
        echo "Opening port $PORT using UFW..."
        
        # Enable UFW if not already enabled
        execute_with_error_check sudo ufw enable || exit 1
        
        # Open the port
        execute_with_error_check sudo ufw allow $PORT || exit 1
        
        echo "Port $PORT has been opened."
    fi
    
    # Replace or add the TOKEN in .env file
    echo "Replacing or adding TOKEN in .env file..."
    TOKEN=$(python3 -c 'import uuid; print(uuid.uuid4().hex)')
    if grep -q "^TOKEN=" .env; then
        execute_with_error_check sed -i "s/^TOKEN=.*/TOKEN=$TOKEN/" .env || exit 1
    else
        echo "TOKEN=$TOKEN" >> .env
    fi
    
    echo "Unique token has been set in .env file."
else
    echo ".env file not found. Creating .env file with a unique token..."
    TOKEN=$(python3 -c 'import uuid; print(uuid.uuid4().hex)')
    echo "TOKEN=$TOKEN" > .env || exit 1
    echo ".env file created and token added."
fi
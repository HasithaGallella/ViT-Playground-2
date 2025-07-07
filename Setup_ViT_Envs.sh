#!/bin/bash

# Script to set up PyTorch and codebase environments with CUDA support
# Designed by Hasitha Gallella, The script is to be run multiple times - skips completed steps automatically
#
# 1. Save the script: nano Setup_ViT_Envs.sh (Paste the code and save)
# 2. Make it executable: chmod +x Setup_ViT_Envs.sh
# 3. Run the script: bash Setup_ViT_Envs.sh 
#



set -e  # Exit on any error

echo "=== PyTorch Environment Setup Script ==="

# Function to check if conda is available
check_conda() {
    if command -v conda &> /dev/null; then
        echo "✓ Conda/Miniconda found"
        return 0
    else
        echo "✗ Conda/Miniconda not found. Please install Anaconda or Miniconda first."
        echo "After installation, run this script again."
        exit 1
    fi
}

# Function to check CUDA driver version
check_cuda_driver() {
    echo "Checking CUDA driver version..."
    
    if command -v nvidia-smi &> /dev/null; then
        # Get driver version
        DRIVER_VERSION=$(nvidia-smi --query-gpu=driver_version --format=csv,noheader,nounits | head -1)
        echo "Current NVIDIA driver version: $DRIVER_VERSION"
        
        # Compare with minimum required version (525.60.13)
        REQUIRED_VERSION="525.60.13"
        
        # Convert versions to comparable format
        current_version_num=$(echo $DRIVER_VERSION | awk -F. '{printf "%d%03d%03d\n", $1,$2,$3}')
        required_version_num=$(echo $REQUIRED_VERSION | awk -F. '{printf "%d%03d%03d\n", $1,$2,$3}')
        
        if [ "$current_version_num" -ge "$required_version_num" ]; then
            echo "✓ CUDA driver version is compatible (>= $REQUIRED_VERSION)"
            return 0
        else
            echo "✗ CUDA driver version $DRIVER_VERSION is too old."
            echo "Please update your NVIDIA driver to version $REQUIRED_VERSION or newer."
            echo "After updating the driver, run this script again."
            exit 1
        fi
    else
        echo "✗ nvidia-smi not found. Please install NVIDIA drivers first."
        echo "After installation, run this script again."
        exit 1
    fi
}

# Function to create conda environment (only if it doesn't exist)
create_conda_env() {
    echo "Checking conda environment 'vit1'..."
    
    # Check if environment already exists
    if conda env list | grep -q "^vit1 "; then
        echo "✓ Conda environment 'vit1' already exists - skipping creation"
        return 0
    else
        echo "Creating conda environment 'vit1' with Python 3.10..."
        conda create -n vit1 python=3.10 pip -y
        echo "✓ Conda environment 'vit1' created successfully"
    fi
}

# Function to check if PyTorch is already installed with correct version
check_pytorch_installed() {
    # Initialize conda for bash
    eval "$(conda shell.bash hook)"
    
    # Try to activate environment and check PyTorch
    if conda activate vit1 2>/dev/null; then
        # Check if PyTorch 2.5.0 with CUDA 12.1 is installed
        PYTORCH_CHECK=$(python -c "
                        import sys
                        try:
                            import torch
                            if torch.__version__.startswith('2.5.0') and torch.cuda.is_available():
                                cuda_version = torch.version.cuda
                                if cuda_version and cuda_version.startswith('12.1'):
                                    print('INSTALLED')
                                else:
                                    print('WRONG_CUDA')
                            else:
                                print('WRONG_VERSION')
                        except ImportError:
                            print('NOT_INSTALLED')
                        " 2>/dev/null)
        
        if [ "$PYTORCH_CHECK" = "INSTALLED" ]; then
            echo "✓ PyTorch 2.5.0 with CUDA 12.1 already installed - skipping installation"
            return 0
        else
            echo "PyTorch not installed or wrong version - will install"
            return 1
        fi
    else
        echo "Cannot activate vit1 environment"
        return 1
    fi
}

# Function to activate environment and install PyTorch
install_pytorch() {
    echo "Activating conda environment 'vit1'..."
    
    # Initialize conda for bash
    eval "$(conda shell.bash hook)"
    conda activate vit1
    
    echo "Installing PyTorch with CUDA 12.1 support..."
    conda install pytorch==2.5.0 torchvision==0.20.0 torchaudio==2.5.0 pytorch-cuda=12.1 -c pytorch -c nvidia -y
    
    if [ $? -eq 0 ]; then
        echo "✓ PyTorch installed successfully!"
    else
        echo "✗ Failed to install PyTorch"
        exit 1
    fi
}

# Function to check if requirements.txt packages are installed
check_requirements_installed() {
    if [ ! -f "requirements.txt" ]; then
        echo "⚠ requirements.txt not found - skipping package installation check"
        return 1
    fi
    
    # Initialize conda for bash
    eval "$(conda shell.bash hook)"
    conda activate vit1 2>/dev/null
    
    # Simple check - if any package from requirements.txt is missing, reinstall all
    echo "Checking if requirements.txt packages are installed..."
    
    # Read requirements and check if packages are installed
    while IFS= read -r package || [ -n "$package" ]; do
        # Skip empty lines and comments
        if [[ -z "$package" || "$package" =~ ^[[:space:]]*# ]]; then
            continue
        fi
        
        # Extract package name (before == or >= etc.)
        package_name=$(echo "$package" | sed 's/[><=!].*//' | sed 's/[[:space:]].*//')
        
        if ! python -c "import $package_name" 2>/dev/null; then
            echo "Package $package_name not found - will install requirements"
            return 1
        fi
    done < requirements.txt
    
    echo "✓ All requirements.txt packages appear to be installed - skipping installation"
    return 0
}

# Function to install additional Python packages
install_python_packages() {
    echo "Installing required Python packages..."
    
    # Check if requirements.txt exists
    if [ ! -f "requirements.txt" ]; then
        echo "⚠ requirements.txt not found in current directory"
        echo "Please ensure requirements.txt exists or create it with your package dependencies"
        return 0
    fi
    
    # Initialize conda for bash
    eval "$(conda shell.bash hook)"
    conda activate vit1
    
    pip install -r requirements.txt
    
    if [ $? -eq 0 ]; then
        echo "✓ Python packages installed successfully!"
    else
        echo "✗ Failed to install Python packages. Please check requirements.txt."
        exit 1
    fi
}

# Main execution flow
main() {
    echo "Starting environment setup (re-runnable)..."
    echo ""
    
    # Step 1: Check conda (will exit if not available)
    check_conda
    echo ""
    
    # Step 2: Check CUDA driver (will exit if not compatible)
    check_cuda_driver
    echo ""
    
    # Step 3: Create conda environment (skip if exists)
    create_conda_env
    echo ""
    
    # Step 4: Install PyTorch (skip if already installed correctly)
    if check_pytorch_installed; then
        echo ""
    else
        install_pytorch
        echo ""
    fi
    
    # Step 5: Install requirements.txt packages (skip if already installed)
    if check_requirements_installed; then
        echo ""
    else
        install_python_packages
        echo ""
    fi
    
    echo "=== Setup Complete ==="
    echo "Environment 'vit1' is ready to use!"
    echo ""
    echo "To activate your environment:"
    echo "conda activate vit1"
    echo ""
    echo "To verify installation:"
    echo "python -c \"import torch; print(f'PyTorch: {torch.__version__}'); print(f'CUDA: {torch.cuda.is_available()}')\""
}

# Run main function
main
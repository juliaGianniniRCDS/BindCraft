#!/bin/bash
################## BindCraft installation script
################## specify conda/mamba folder, and installation folder for git repositories, and whether to use mamba or $pkg_manager
# Default value for pkg_manager
pkg_manager='mamba'
cuda='12.6'
cuda_l='126'

# Define the short and long options
OPTIONS=p:c:
LONGOPTIONS=pkg_manager:,cuda:

# Parse the command-line options
PARSED=$(getopt --options=$OPTIONS --longoptions=$LONGOPTIONS --name "$0" -- "$@")
eval set -- "$PARSED"

# Process the command-line options
while true; do
  case "$1" in
    -p|--pkg_manager)
      pkg_manager="$2"
      shift 2
      ;;
    -c|--cuda)
      cuda="$2"
      shift 2
      ;;
    --)
      shift
      break
      ;;
    *)
      echo -e "Invalid option $1" >&2
      exit 1
      ;;
  esac
done

# Example usage of the parsed variables
echo -e "Package manager: $pkg_manager"
echo -e "CUDA: $cuda"

############################################################################################################
############################################################################################################
################## initialisation
SECONDS=0

## Quest: load modules
module purge
module load mamba/24.3.0
module load git/2.37.2

# set paths needed for installation and check for conda installation
install_dir=$(pwd)
CONDA_BASE=$(conda info --base 2>/dev/null) || { echo -e "Error: conda is not installed or cannot be initialised."; exit 1; }
echo -e "Conda is installed at: $CONDA_BASE"

env_prefix_relative=${install_dir}/../env/BindCraft
env_prefix=$(realpath "${env_prefix_relative}")

## For part install/debugging
install_env=0
build_env=1

### BindCraft install begin, create base environment
if [ "$install_env" -eq 1 ]; then
	echo -e "Installing BindCraft environment\n"
	$pkg_manager create --prefix=${env_prefix} python=3.10 -y || { echo -e "Error: Failed to create BindCraft conda environment"; exit 1; }
else
	echo -e "Not installing environment, attempting to activate and use existing environment\n"
fi

# Check if env exists
conda env list | grep -w 'BindCraft' >/dev/null 2>&1 || { echo -e "Error: Conda environment 'BindCraft' does not exist after creation."; exit 1; }

# Load BindCraft environment
echo -e "Loading BindCraft environment\n"
source activate ${env_prefix} || { echo -e "Error: Failed to activate the BindCraft environment."; exit 1; }
echo $CONDA_DEFAULT_ENV
echo ${env_prefix}
[[ "$CONDA_DEFAULT_ENV" == "${env_prefix}" ]] || { echo -e "Error: The BindCraft environment is not active."; exit 1; }
echo -e "BindCraft environment activated at ${env_prefix}"

# install required conda packages
if [ "$build_env" -eq 1 ]; then
	echo -e "Instaling conda requirements\n"
	if [ -n "$cuda" ]; then
    		CONDA_OVERRIDE_CUDA="$cuda" $pkg_manager install cuda-version=$cuda pip pandas matplotlib numpy"<2.0.0" biopython scipy pdbfixer seaborn libgfortran5 tqdm jupyter ffmpeg pyrosetta fsspec py3dmol chex dm-haiku flax"<0.10.0" dm-tree joblib ml-collections immutabledict optax jaxlib=0.6.0=*cuda$cuda_l* jax cuda-nvcc cudnn -c conda-forge -c nvidia  --channel https://conda.graylab.jhu.edu -y || { echo -e "Error: Failed to install conda packages."; exit 1; }
	else
    		$pkg_manager install pip pandas matplotlib numpy"<2.0.0" biopython scipy pdbfixer seaborn libgfortran5 tqdm jupyter ffmpeg pyrosetta fsspec py3dmol chex dm-haiku flax"<0.10.0" dm-tree joblib ml-collections immutabledict optax jaxlib jax cuda-nvcc cudnn -c conda-forge -c nvidia  --channel https://conda.graylab.jhu.edu -y || { echo -e "Error: Failed to install conda packages."; exit 1; }
	fi
else
	echo -e "Not installing packages, attempting to use already installed packages."
fi

# make sure all required packages were installed
required_packages=(pip pandas libgfortran5 matplotlib numpy biopython scipy pdbfixer seaborn tqdm jupyter ffmpeg pyrosetta fsspec py3dmol chex dm-haiku dm-tree joblib ml-collections immutabledict optax jaxlib jax cuda-nvcc cudnn)
missing_packages=()

# Check each package
for pkg in "${required_packages[@]}"; do
    conda list "$pkg" | grep -w "$pkg" >/dev/null 2>&1 || missing_packages+=("$pkg")
done

# If any packages are missing, output error and exit
if [ ${#missing_packages[@]} -ne 0 ]; then
    echo -e "Error: The following packages are missing from the environment:"
    for pkg in "${missing_packages[@]}"; do
        echo -e " - $pkg"
    done
    exit 1
fi

# install ColabDesign
echo -e "Installing ColabDesign\n"
pip3 install git+https://github.com/sokrypton/ColabDesign.git --no-deps || { echo -e "Error: Failed to install ColabDesign"; exit 1; }
python -c "import colabdesign" >/dev/null 2>&1 || { echo -e "Error: colabdesign module not found after installation"; exit 1; }

# AlphaFold2 weights

# symlink to AF2 weights
params_dir="/software/AlphaFold/data/v2.3.2/params"
echo -e "Making symbolic link for AF2 model weights at ${params_dir}\n"
ln -s ${params_dir} ${install_dir}/params || { echo -e "Error: failed to symlink."; exit 1; }

# chmod executables
echo -e "Changing permissions for executables\n"
chmod +x "${install_dir}/functions/dssp" || { echo -e "Error: Failed to chmod dssp"; exit 1; }
chmod +x "${install_dir}/functions/DAlphaBall.gcc" || { echo -e "Error: Failed to chmod DAlphaBall.gcc"; exit 1; }

# finish
source deactivate
echo -e "BindCraft environment set up\n"

############################################################################################################
############################################################################################################
################## cleanup
echo -e "Cleaning up ${pkg_manager} temporary files to save space\n"
$pkg_manager clean -a -y
echo -e "$pkg_manager cleaned up\n"

################## finish script
t=$SECONDS 
echo -e "Successfully finished BindCraft installation!\n"
echo -e "Activate environment using command: \"$pkg_manager activate ${env_prefix}\""
echo -e "\n"
echo -e "Installation took $(($t / 3600)) hours, $((($t / 60) % 60)) minutes and $(($t % 60)) seconds."

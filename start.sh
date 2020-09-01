#!/bin/bash
# DISCLAIMER: IANABE (I am not a bash expert).
# I've tried very hard to make this transparent, readable and secure. If there
# are any gaps/improvements to be made, please submit a PR. 🙌🏽

# COLOR VARIABLES
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# STEPS
TOTAL_STEPS=12
CURRENT_STEP=1

# GRÜVEE VARIABLES
GRUVEE_MOBILE_REPO_NAME=Gruvee-Mobile
GRUVEE_BACKEND_REPO_NAME=gruveebackend
GRUVEE_MOBILE_GIT=https://github.com/PixelogicDev/Gruvee-Mobile.git
GRUVEE_BACKEND_GIT=https://github.com/PixelogicDev/gruveebackend.git

# MESSAGE FUNCTIONS
error() {
  local message="$1"
  printf "\e[0;31mError:\e[0m %s" "$message"
  exit 1
}

success() {
  local message="$1"
  printf "\e[0;32mSuccess:\e[0m %s" "$message"
}

cprint() {
  printf "$1$2 ${NC}\n"
}

stepprint() {
  cprint "$CYAN" "[${CURRENT_STEP}/${TOTAL_STEPS}] $1 ${NC}"
  ((++CURRENT_STEP))
}

print_check_tick() {
  cprint "$GREEN" "[✓] $1"
}

print_check_cross() {
  cprint "$RED" "[x] $1"
}

print_check_empty() {
  cprint "$CYAN" "[ ] $1"
}

prompt_yn() {
  printf "$MAGENTA"
  read -p "$1 (Y/n) " -n 1 -r user_input
  printf "\n"
  printf "$NC"
  if [[ "$user_input" =~ ^[Yy]$ ]]; then
    return 0
  else
    return 1
  fi
}

# OS OPTIONS
# if [ "$(uname)" == "Darwin" ]; then
#     # Do something under Mac OS X platform
# elif [ "$(expr substr $(uname -s) 1 5)" == "Linux" ]; then
#     # Do something under GNU/Linux platform
# elif [ "$(expr substr $(uname -s) 1 10)" == "MINGW32_NT" ]; then
#     # Do something under 32 bits Windows NT platform
# elif [ "$(expr substr $(uname -s) 1 10)" == "MINGW64_NT" ]; then
#     # Do something under 64 bits Windows NT platform
# fi

# SCRIPT FUNCTIONS

print_packages() {
  for prereqs in "${installed[@]}"; do
    print_check_tick "$prereqs"
  done

  for prereqs in "${not_installed[@]}"; do
    print_check_cross "$prereqs"
  done

  if [[ ! ${#not_installed[@]} -eq 0 ]]; then
    error "Please download the missing pre-requisites and run the script again!"
  fi

  installed=()
  not_installed=()
}

check_prerequisites() {
  check_package() {
    if command -v "$1" >/dev/null 2>/dev/null; then
      installed+=("$2 installed")
    else
      not_installed+=("$2 not installed - install here: $3")
    fi
  }

  stepprint "Checking pre-requisites"
  check_package git git https://git-scm.com/book/en/v2/Getting-Started-Installing-Git
  check_package node node https://nodejs.org/en/download/
  check_package go GO https://golang.org/dl/

  if [[ "$(uname)" == "Darwin" ]]; then
    if prompt_yn "Are you planning to do iOS development with Grüvee?" "user_ios_confirm"; then
      ios_dev=true
      check_package xcode-select Xcode https://apps.apple.com/us/app/xcode/id497799835
      check_package pod CocoaPods https://cocoapods.org/
    else
      ios_dev=false
    fi

  fi

  if prompt_yn "Are you planning to do Android development with Grüvee?" "user_jdk_confirm"; then
    android_dev=true
    check_package java java https://java.com/en/download/help/download_options.xml
    check_package javac jdk https://docs.oracle.com/en/java/javase/11/install/overview-jdk-installation.html#GUID-8677A77F-231A-40F7-98B9-1FD0B48C346A
  else
    android_dev=false
  fi

  print_packages

}

check_versions() {
  check_version_of_package() {
    version=$("$1" -v)

    if [[ "$version" = "$3" ]]; then
      installed+=("$2 is currently at the correct version: $3")
    else
      not_installed+=("$2 is currently at $version - which is not the right version: $3")
    fi

    print_packages

    ## CHECK VERSIONS:
    ## SET DELIMETER ON READ OF VERSION AND SET VARIABLES
    ## OR BASH HAS SUBSTRINGS TLDP
    # while IFS='.' read -ra "$version"; do
    #
    # done <<<"$IN"

  }

  stepprint "Checking versions of pre-requisites"
  check_version_of_package node node "v12.16.3"
  # TODO: Docs require "jdk" (actually Java) =<11.0 however commands `javac -version` are appended with "1."
  # check_version_of_package java java "v12.16.3"

}

check_simualtors() {
  $ios_dev || $android_dev && stepprint "Checking simulators are installed"

  if $ios_dev; then
    # Checks if ios simulator CLI is available
    # TODO this command works in terminal but doesn't work in this if statement
    if command xcrun simctl --help >/dev/null 2>/dev/null; then
      installed+=("ios simulator is installed")
    else
      not_installed+=("ios simulator is not installed")
    fi
  fi

  if $android_dev; then
    # Checks if android simulator CLI is available
    if command emulator -help >/dev/null 2>/dev/null; then
      installed+=("android emulator is installed")
    else
      not_installed+=("android emulator is not installed")
    fi
  fi

  print_packages
}

community() {
  stepprint "Pixelogic Crew"
  if prompt_yn "Do you want to be a part of the Pixelogic Community?"; then
    cprint "$RED" "Come join us here: https://discord.gg/6qKsZ5p"
  fi
}

declare_working_directory() {
  printf "$MAGENTA"
  stepprint "Declaring working directory"
  printf "$MAGENTA"
  read -p "Please type the path you want to clone Grüvee into: ($PWD)" user_clone_path
  if [[ -d "$user_clone_path" ]]; then
    clone_path="$user_clone_path"
  else
    clone_path="$PWD"
  fi
  read -p "Is ($clone_path) correct? (Y/n)" -n 1 -r user_clone_path_confirm
  printf "$NC\n"

  if [[ "$user_clone_path_confirm" =~ ^[Yy]$ ]]; then
    cd "$clone_path"
  else
    declare_working_directory
  fi
  printf "$NC"
}

clone_repositories() {
  clone() {
    if [[ ! -d $1 ]]; then
      stepprint "Cloning $1 from $2"
      command git clone "$2"
    else
      stepprint "$1 already cloned from $2"
    fi

  }
  clone "$GRUVEE_MOBILE_REPO_NAME" "$GRUVEE_MOBILE_GIT"
  clone "$GRUVEE_BACKEND_REPO_NAME" "$GRUVEE_BACKEND_GIT"
}

set_up_environmental_variables() {
  echo ""
}

# SCRIPT STRE
header() {
  printf " ${GREEN}
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
|                                                                           |
+   _______  ______    __   __  __   __  _______  _______                   +
|  |       ||    _ |  |__| |__||  | |  ||       ||       |                  |
+  |    ___||   | ||   __   __ |  |_|  ||    ___||    ___|                  +
|  |   | __ |   |_||_ |  |_|  ||       ||   |___ |   |___                   |
+  |   ||  ||    __  ||       ||       ||    ___||    ___|                  +
|  |   |_| ||   |  | ||       | |     | |   |___ |   |___                   |
+  |_______||___|  |_||_______|  |___|  |_______||_______|                  +
|                                                                           |
+                 _            , __              _                          +
|                | |          /|/  \o           | |           o             |
+                | |           |___/         _  | |  __   __,     __        +
|                |/ \_|   |    |    |  /\/  |/  |/  /  \_/  | |  /          |
+                 \_/  \_/|/   |    |_/ /\_/|__/|__/\__/ \_/|/|_/\___/      +
|                        /|                                /|               |
+                        \|                                \|               +
|                                                                           |
+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
${MAGENTA}Hi, welcome to the Grüvee by Pixelogic install script. \n
This will help get you up and running with your own Grüvee dev environment. \n
-----------------------------------------------------------------------------
${NC}
"
}
cd "$(dirname "$0")"

# SCRIPT START
header
community
check_prerequisites
check_versions
check_simualtors
declare_working_directory
clone_repositories
# set_up_environmental_variables

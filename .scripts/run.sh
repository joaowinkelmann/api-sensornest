#!/usr/bin/bash

# Variables
APP_NAME="api-tempmesh"
APP_DIR="/var/www/html/$APP_NAME"
LOG_FILE="$APP_DIR/run-deployment.log"

# Log function to track execution
log() {
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] $1" | tee -a "$LOG_FILE"
}

# Error handling function
handle_error() {
  log "ERROR: $1"
  exit 1
}

# Check if command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Create log directory if it doesn't exist
mkdir -p "$(dirname "$LOG_FILE")"

log "Starting deployment process for $APP_NAME"

# Export the path to bun
export PATH="$HOME/.bun/bin:$PATH"

# Source NVM and bun environments
export NVM_DIR="$HOME/.config/nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" || handle_error "NVM script not found. Please install NVM first"

# Check for required tools
if ! command_exists nvm; then
  handle_error "NVM is not installed. Please install it first: https://github.com/nvm-sh/nvm#installing-and-updating"
fi

if ! command_exists bun; then
  log "Bun not found. Installing Bun..."
  curl -fsSL https://bun.sh/install | bash || handle_error "Failed to install Bun"
  export PATH="$HOME/.bun/bin:$PATH"
  log "Bun installed successfully"
fi

if ! command_exists pm2; then
  log "PM2 not found. Installing PM2..."
  npm install -g pm2 || handle_error "Failed to install PM2"
  log "PM2 installed successfully"
fi

# Change to application directory
cd $APP_DIR || handle_error "Directory $APP_DIR not found"
log "Running script inside $APP_DIR"

# Setup Node environment
log "Setting up Node environment..."
nvm install --lts || handle_error "Failed to install LTS Node version"
nvm use --lts || handle_error "Failed to use LTS Node version"
log "Using Node $(node -v)"

# Update Bun and dependencies
log "Updating Bun and dependencies..."
bun upgrade || handle_error "Failed to upgrade Bun"
log "Running Bun $(bun --revision)"
bun install || handle_error "Failed to install dependencies"

# Run database migrations and generate Prisma client
bunx prisma migrate deploy || handle_error "Failed to run Prisma migrations"
bunx prisma generate || handle_error "Failed to generate Prisma client"

bun update || handle_error "Failed to update dependencies"

# Build application
log "Building application..."
bun run build || handle_error "Build failed"
log "Build completed successfully"

# Manage PM2 process
if pm2 show $APP_NAME &> /dev/null; then
  log "Restarting $APP_NAME application..."
  pm2 restart $APP_NAME || handle_error "Failed to restart application with PM2"
else
  log "Starting $APP_NAME application..."
  pm2 start bun --name "$APP_NAME" -- run start || handle_error "Failed to start application with PM2"
fi

# Save PM2 configuration and setup startup
log "Saving PM2 configuration..."
pm2 save || handle_error "Failed to save PM2 configuration"

# Setup PM2 to start on system boot (with sudo if needed)
log "Setting up PM2 startup..."
pm2 startup | grep -v "ignore" > /tmp/pm2_startup_command.sh
chmod +x /tmp/pm2_startup_command.sh
/tmp/pm2_startup_command.sh || log "Warning: PM2 startup command may require sudo privileges. Run the generated command manually."

log "Deployment completed successfully"
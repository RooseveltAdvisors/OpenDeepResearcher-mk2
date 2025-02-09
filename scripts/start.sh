#!/bin/bash

echo "🚀 Starting Open Deep Research..."

# Function to read XML values
get_xml_value() {
    local xpath=$1
    xmllint --xpath "string($xpath)" env-config.xml
}

# Get environment name from config
CONDA_ENV_NAME=$(get_xml_value "/config/environment/name")

# Check if conda environment exists and activate it
if conda env list | grep -q "$CONDA_ENV_NAME"; then
    echo "🐍 Activating Python environment: $CONDA_ENV_NAME..."
    eval "$(conda shell.bash hook)"
    conda activate "$CONDA_ENV_NAME"
else
    echo "❌ Conda environment not found. Please run ./scripts/init.sh first"
    exit 1
fi

# Load environment variables
echo "🔄 Loading environment variables..."
set -a # automatically export all variables
source .env
set +a

# Function to check if services are running
check_services() {
    if ! docker-compose ps | grep -q "postgres-db.*running"; then
        echo "🔄 PostgreSQL not detected. Starting services..."
        docker-compose up -d
        sleep 5
    fi
}

# Check and start services if needed
check_services

# Export database URLs explicitly for the build process
export POSTGRES_URL="postgresql://postgres:postgres@localhost:5432/chatdb"
export DATABASE_URL="$POSTGRES_URL"

# Start the web server
echo "🌐 Starting web server..."
if [ -f ~/.npm-global/bin/pnpm ]; then
    ~/.npm-global/bin/pnpm build && ~/.npm-global/bin/pnpm start
else
    npm run build && npm start
fi

echo "✅ Application is starting up! Please wait..."
echo "📝 The application will be available at http://localhost:3000" 
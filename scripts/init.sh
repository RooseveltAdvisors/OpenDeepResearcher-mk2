#!/bin/bash

echo "🚀 Initializing Open Deep Research for first time setup..."

# Check if conda environment exists
if conda env list | grep -q "$CONDA_ENV_NAME"; then
  echo "⚠️ This will reset your environment, database, and configurations. Are you sure? (y/N)"
  read -r response
  if [[ ! "$response" =~ ^[Yy]$ ]]; then
      echo "❌ Initialization cancelled"
      exit 1
  fi
else
  echo "🆕 First time setup - creating new environment..."
fi

# Function to read XML values
get_xml_value() {
    local xpath=$1
    xmllint --xpath "string($xpath)" env-config.xml
}

# Get environment name from config
CONDA_ENV_NAME=$(get_xml_value "/config/environment/name")

# Check if conda is installed
if ! command -v conda &> /dev/null; then
    echo "❌ Conda is not installed. Please install Miniconda or Anaconda first."
    echo "📝 Download from: https://docs.conda.io/en/latest/miniconda.html"
    exit 1
fi

# Check if xmllint is installed
if ! command -v xmllint &> /dev/null; then
    echo "❌ xmllint is not installed. Installing libxml2-utils..."
    if command -v apt &> /dev/null; then
        sudo apt install -y libxml2-utils
    elif command -v brew &> /dev/null; then
        brew install libxml2
    else
        echo "❌ Please install libxml2-utils manually"
        exit 1
    fi
fi

# Function to check and kill processes using a port
check_port() {
    local port=$1
    echo "🔍 Checking port $port..."
    
    # Try to stop system PostgreSQL if it's port 5432
    if [ "$port" = "5432" ]; then
        echo "Stopping system PostgreSQL service if running..."
        sudo service postgresql stop 2>/dev/null || true
        sudo systemctl stop postgresql 2>/dev/null || true
        sudo systemctl stop postgresql@* 2>/dev/null || true
    fi

    # Find and kill any process using the port
    while lsof -i ":$port" >/dev/null 2>&1; do
        echo "⚠️ Port $port is in use. Attempting to free it..."
        sudo lsof -i ":$port" | grep LISTEN | awk '{print $2}' | xargs -r sudo kill -9
        sleep 2
    done
}

# Clean up function
cleanup_docker() {
    echo "🧹 Cleaning up Docker resources..."
    docker-compose down --remove-orphans
    docker rm -f postgres-db 2>/dev/null || true
    docker network prune -f
    # Remove old node_modules to prevent dependency conflicts
    rm -rf node_modules
    rm -f pnpm-lock.yaml
}

# Initial cleanup
echo "🛑 Cleaning up existing services..."
cleanup_docker
check_port 5432  # PostgreSQL

# Remove existing environment if it exists
conda env remove -n "$CONDA_ENV_NAME" -y 2>/dev/null || true

# Create and activate conda environment with Node.js
echo "🐍 Setting up Python and Node.js environment..."
conda create -n "$CONDA_ENV_NAME" python=3.11 nodejs=20 -c conda-forge -y
eval "$(conda shell.bash hook)"
conda activate "$CONDA_ENV_NAME"

# Verify Node.js and npm installation
if ! command -v node &> /dev/null || ! command -v npm &> /dev/null; then
    echo "❌ Node.js or npm not found. Installing via conda-forge..."
    conda install -c conda-forge nodejs=20 -y
fi

# Set up npm global directory
echo "📦 Configuring npm..."
mkdir -p ~/.npm-global
npm config set prefix ~/.npm-global
export PATH=~/.npm-global/bin:$PATH

# Install pnpm using npm
echo "📦 Installing pnpm..."
npm install -g pnpm
hash -r

# Create .npmrc
echo "📝 Creating .npmrc..."
echo "strict-peer-dependencies=false" > .npmrc
echo "auto-install-peers=true" >> .npmrc
echo "legacy-peer-deps=true" >> .npmrc

# Check if .env exists, if not create it
if [ ! -f .env ]; then
    echo "📝 Creating .env file..."
    echo "AUTH_SECRET='$(openssl rand -base64 32)'" > .env
    echo "POSTGRES_URL='postgresql://postgres:postgres@localhost:5432/chatdb'" >> .env
    echo "NEXTAUTH_URL='http://devbox.intellinum.co:3000'" >> .env
    echo "NEXTAUTH_URL_INTERNAL='http://devbox.intellinum.co:3000'" >> .env
    echo "AUTH_TRUST_HOST='devbox.intellinum.co'" >> .env
    echo "⚠️ Please add your API keys to .env file:"
    echo "OPENAI_API_KEY='your-openai-key'" >> .env
    echo "OPENROUTER_API_KEY='your-openrouter-key'" >> .env
    echo "FIRECRAWL_API_KEY='your-firecrawl-key'" >> .env
fi

# Remove any existing Upstash Redis variables if they exist
if [ -f .env ]; then
    sed -i '/UPSTASH_REDIS_REST_URL/d' .env
    sed -i '/UPSTASH_REDIS_REST_TOKEN/d' .env
    sed -i '/REDIS_URL/d' .env
fi

# Update existing .env with correct database URL if needed
if grep -q "DATABASE_URL" .env; then
    echo "📝 Updating database URL variable name..."
    sed -i 's/DATABASE_URL/POSTGRES_URL/' .env
fi

# Ensure POSTGRES_URL exists
if ! grep -q "POSTGRES_URL" .env; then
    echo "📝 Adding POSTGRES_URL to .env..."
    echo "POSTGRES_URL=\"postgresql://postgres:postgres@localhost:5432/chatdb\"" >> .env
fi

# Install dependencies
echo "📦 Installing project dependencies..."
echo "📦 Installing PDF support..."
pnpm add pdf-lib

echo "📦 Installing other dependencies..."
pnpm install

# Start database and wait for it to be ready
echo "🐘 Starting PostgreSQL..."
docker-compose up -d

# Wait for PostgreSQL to be ready with more detailed feedback
echo "⏳ Waiting for PostgreSQL..."
for i in {1..30}; do
    if [ ! "$(docker ps -q -f name=postgres-db)" ]; then
        echo "❌ PostgreSQL container failed to start. Retrying..."
        cleanup_docker
        check_port 5432
        docker-compose up -d
        sleep 2
        continue
    fi
    
    if docker-compose exec -T postgres pg_isready -U postgres >/dev/null 2>&1; then
        echo "✅ PostgreSQL is ready"
        break
    fi
    
    if [ $i -eq 30 ]; then
        echo "❌ PostgreSQL failed to start. Logs:"
        docker-compose logs postgres
        exit 1
    fi
    echo -n "."
    sleep 1
done

# Before running migrations, let's ensure environment variables are loaded
echo "🔄 Loading environment variables..."
set -a # automatically export all variables
source .env
set +a

# Create migrations directory structure
echo "📁 Setting up migrations directory..."
mkdir -p lib/db/migrations/meta
touch lib/db/migrations/meta/_journal.json

# Initialize _journal.json if empty
if [ ! -s lib/db/migrations/meta/_journal.json ]; then
    echo "📝 Initializing migration journal..."
    echo '{
  "version": "5",
  "dialect": "pg",
  "entries": []
}' > lib/db/migrations/meta/_journal.json
fi

# Create initial migration if it doesn't exist
if [ ! -f lib/db/migrations/0000_initial.sql ]; then
    echo "📝 Creating initial migration..."
    echo '-- Initial migration
CREATE TABLE IF NOT EXISTS chats (
    id SERIAL PRIMARY KEY,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);' > lib/db/migrations/0000_initial.sql
fi

# Run migrations with explicit database URL
echo "🔄 Running database migrations..."
DATABASE_URL="postgresql://postgres:postgres@localhost:5432/chatdb" \
POSTGRES_URL="postgresql://postgres:postgres@localhost:5432/chatdb" \
pnpm db:migrate

echo "✅ Initialization complete! You can now use ./scripts/start.sh to run the application"
echo "⚠️ Remember to activate the conda environment with: conda activate $CONDA_ENV_NAME" 
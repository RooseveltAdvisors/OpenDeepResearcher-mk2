# Open Deep Research

An Open-Source clone of Open AI's Deep Research experiment. Instead of using a fine-tuned version of o3, this method uses [Firecrawl's extract + search](https://firecrawl.dev/) with a reasoning model to deep research the web.

Check out the demo [here](https://x.com/nickscamara_/status/1886459999905521912)

![Open Deep Research Hero](public/open-deep-researched-pic.png)

## Features

- [Firecrawl](https://firecrawl.dev) Search + Extract
  - Feed realtime data to the AI via search
  - Extract structured data from multiple websites via extract
- [Next.js](https://nextjs.org) App Router
  - Advanced routing for seamless navigation and performance
  - React Server Components (RSCs) and Server Actions for server-side rendering and increased performance
- [AI SDK](https://sdk.vercel.ai/docs)
  - Unified API for generating text, structured objects, and tool calls with LLMs
  - Hooks for building dynamic chat and generative user interfaces
  - Supports OpenAI (default), Anthropic, Cohere, and other model providers
- [shadcn/ui](https://ui.shadcn.com)
  - Styling with [Tailwind CSS](https://tailwindcss.com)
  - Component primitives from [Radix UI](https://radix-ui.com) for accessibility and flexibility
- Data Persistence
  - PostgreSQL database (via Docker) for saving chat history and user data
- In-memory rate limiting for API protection

Both databases are automatically configured when you run the application using Docker Compose:

```bash
docker-compose up -d
```

Environment variables for database connections:
```bash
# PostgreSQL connection
DATABASE_URL="postgresql://postgres:postgres@localhost:5432/chatdb"

# Redis connection
REDIS_URL="redis://localhost:6379"
```

### Useful Docker Commands

```bash
# Start all services (PostgreSQL and Redis)
docker-compose up -d

# Stop all services
docker-compose down

# View logs for all services
docker-compose logs -f

# View logs for specific service
docker-compose logs -f postgres
docker-compose logs -f redis

# Stop services but keep volumes
docker-compose down

# Stop services and remove volumes
docker-compose down -v

# Access database CLIs
docker-compose exec postgres psql -U postgres -d chatdb
docker-compose exec redis redis-cli
```

- Local file storage for uploads
- [NextAuth.js](https://github.com/nextauthjs/next-auth)
  - Simple and secure authentication

## Model Providers

This template ships with OpenAI `gpt-4o` as the default. However, with the [AI SDK](https://sdk.vercel.ai/docs), you can switch LLM providers to [OpenAI](https://openai.com), [Anthropic](https://anthropic.com), [Cohere](https://cohere.com/), and [many more](https://sdk.vercel.ai/providers/ai-sdk-providers) with just a few lines of code.

This repo is compatible with [OpenRouter](https://openrouter.ai/) and [OpenAI](https://openai.com/). To use OpenRouter, you need to set the `OPENROUTER_API_KEY` environment variable.

## Prerequisites

Before starting, make sure you have:
- [Docker](https://www.docker.com/get-started/) installed
- [Conda](https://docs.conda.io/en/latest/miniconda.html) installed (for Python and Node.js environment)

The initialization script will automatically:
- Create a conda environment with Python and Node.js
- Install pnpm
- Install all required dependencies
- Set up database containers (PostgreSQL and Redis)

## Configuration

The application uses two configuration files:

1. `env-config.xml` for environment name:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<config>
    <environment>
        <name>open-deep-research</name>
    </environment>
</config>
```

2. `environment.yml` for conda environment setup:
```yaml
name: open-deep-research
channels:
  - conda-forge
  - defaults
dependencies:
  - python=3.11
  - nodejs=20
  - npm=10
  - pip
```

## Scripts

The application comes with two utility scripts:

### 1. Initialization Script (`scripts/init.sh`)

This script performs first-time setup and should be run only once. It will:
- Create a new conda environment
- Install all dependencies
- Set up the database
- Create initial configurations

```bash
chmod +x scripts/init.sh
./scripts/init.sh
```

⚠️ **Warning**: Running this script will:
- Reset your conda environment
- Reset your database
- Reset your configurations
- Create new environment files

The script will ask for confirmation before proceeding.

### 2. Start Script (`scripts/start.sh`)

This script starts the application for regular use. It will:
- Activate the conda environment
- Check if services are running
- Start the web server

```bash
chmod +x scripts/start.sh
./scripts/start.sh
```

Use this script for your daily development work. It's safe to run multiple times and won't reset your environment.

## First Time Setup

1. Make the scripts executable:
```bash
chmod +x scripts/init.sh scripts/start.sh
```

2. Run the initialization script (only once):
```bash
./scripts/init.sh
```

3. For subsequent runs, use the start script:
```bash
./scripts/start.sh
```
#!/bin/bash

echo "🔄 Updating Docker Compose commands for compatibility"
echo "===================================================="

# Files to update
files=("quick-diagnosis.sh" "monitor-containers.sh" "fix-debug-script.sh")

for file in "${files[@]}"; do
    if [ -f "$file" ]; then
        echo "Updating $file..."
        
        # Replace docker-compose with $DOCKER_COMPOSE variable
        sed -i.bak 's/docker-compose/\$DOCKER_COMPOSE/g' "$file"
        
        # Add DOCKER_COMPOSE detection at the beginning if not present
        if ! grep -q "DOCKER_COMPOSE=" "$file"; then
            # Create temp file with detection code
            cat > temp_header.txt << 'EOF'
#!/bin/bash

# Detect Docker Compose command (docker-compose or docker compose)
DOCKER_COMPOSE=""
if command -v docker-compose >/dev/null 2>&1; then
    DOCKER_COMPOSE="docker-compose"
elif command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1; then
    DOCKER_COMPOSE="docker compose"
else
    echo "❌ Neither 'docker-compose' nor 'docker compose' found"
    echo "Please install Docker Compose or check if Docker is running"
    exit 1
fi

EOF
            
            # Get the original content without the shebang
            tail -n +2 "$file" > temp_body.txt
            
            # Combine header and body
            cat temp_header.txt temp_body.txt > "$file"
            
            # Clean up
            rm temp_header.txt temp_body.txt
        fi
        
        echo "✅ Updated $file"
    else
        echo "⚠️  $file not found"
    fi
done

echo ""
echo "🧹 Making all scripts executable..."
chmod +x *.sh

echo ""
echo "✅ All scripts updated for Docker Compose compatibility"
echo "Now supports both 'docker-compose' and 'docker compose' commands"
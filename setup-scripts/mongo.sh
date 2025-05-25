#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
inject_db_name_into_mongo_uri(){
    local uri="$1"
    local db_name="$2"

    # Check if there's a query string
    if [[ "$uri" == *\?* ]]; then
        local base="${uri%%\?*}"     # before ?
        local params="${uri#*\?}"    # after ?
    else
        local base="$uri"
        local params=""
    fi

    # Strip trailing slash if present
    base="${base%/}"

    # Rebuild
    if [[ -n "$params" ]]; then
        echo "${base}/${db_name}?${params}"
    else
        echo "${base}/${db_name}"
    fi
}
# --- Main script logic ---

# Mongo DB
LOCAL_MONGO=true
read -p "Do you wish to use a local MongoDB instance? (Y/n) " yn

    case $yn in
        [Yy]* ) LOCAL_MONGO=true;;
        [Nn]* ) LOCAL_MONGO=false;;
        * ) LOCAL_MONGO=true;; # Default to local if input is not Y or N
    esac

if ! $LOCAL_MONGO; then
    # Prompt for MongoDB details
    read -p "Provide MongoDB URL (e.g., mongodb://<db_user>:<db_password>@<db_host>/?param=value): " MONGO_URL
    
    # Store the input URL directly, assuming it's clean and complete
    NEW_MONGO_URI_VALUE="${MONGO_URL}" 
    DOCKER_COMPOSE_FILE="$ROOT_DIR/config-generated/docker-compose.yml" # Define the path to your docker-compose file

    # --- IMPORTANT FIX: Check if the docker-compose file exists ---
    if [ ! -f "${DOCKER_COMPOSE_FILE}" ]; then
        echo "Error: Docker Compose file not found: ${DOCKER_COMPOSE_FILE}" >&2
        echo "Please ensure the file exists before running this script, or create a placeholder." >&2
        exit 1 # Exit if the file isn't found
    fi
    # --- END IMPORTANT FIX ---


    echo "Commenting out local MongoDB service from ${DOCKER_COMPOSE_FILE}..."
    # FIX: Changed 'sed -i '' -e' to 'sed -i -e' for GNU sed compatibility
    sed -i -e '
    /^[[:space:]]\{2\}mongo:$/ {
        s/^/#/;
        :mongo_service_loop
        n;
        /^[[:space:]]\{4\}/ {
            s/^/#/;
            b mongo_service_loop;
        }
    }' "${DOCKER_COMPOSE_FILE}"

    echo "Commenting out local MongoDB volume from ${DOCKER_COMPOSE_FILE}..."
    # FIX: Changed 'sed -i '' -e' to 'sed -i -e' for GNU sed compatibility
    sed -i -e '
    /^[[:space:]]*volumes:$/,/^[^[:space:]]/ {
        /^[[:space:]]\{2\}mongo:$/s/^/#/;
    }' "${DOCKER_COMPOSE_FILE}"

    echo "Commenting out only '- mongo' lines within 'depends_on' blocks in ${DOCKER_COMPOSE_FILE}..."
    # FIX: Changed 'sed -i '' -e' to 'sed -i -e' for GNU sed compatibility
    sed -i -e '
    /^[[:space:]]\{4\}depends_on:$/ {
        n; # Read the next line
        /^[[:space:]]\{6\}-\s*mongo$/ {
            s/^/#/; # Comment out only the "- mongo" line
        }
    }' "${DOCKER_COMPOSE_FILE}"


    echo "MongoDB sections and dependencies commented out from ${DOCKER_COMPOSE_FILE}."    

    if [ -z "${NEW_MONGO_URI_VALUE}" ]; then
        echo "Critical: Failed to generate MongoDB URI. Please check the details provided." >&2
        echo "Skipping update of configuration files due to URI generation failure."
    else
        echo "Generated MongoDB URI: ${NEW_MONGO_URI_VALUE}"

        # --- Define list of configuration files to update ---
        declare -a CONFIG_FILES_TO_UPDATE
        # Using the paths exactly as you provided:
        CONFIG_FILES_TO_UPDATE+=( "$ROOT_DIR/config-generated/config-generated/wildduck/dbs.toml" )
        CONFIG_FILES_TO_UPDATE+=( "$ROOT_DIR/config-generated/config-generated/haraka/wildduck.yaml" )
        CONFIG_FILES_TO_UPDATE+=( "$ROOT_DIR/config-generated/config-generated/zone-mta/dbs-development.toml" )
        CONFIG_FILES_TO_UPDATE+=( "$ROOT_DIR/config-generated/config-generated/zone-mta/dbs-production.toml" )
        CONFIG_FILES_TO_UPDATE+=( "$ROOT_DIR/config-generated/config-generated/wildduck-webmail/default.toml" )
        uri_wildduck=$(inject_db_name_into_mongo_uri "$NEW_MONGO_URI_VALUE" "wildduck")
        uri_webmail=$(inject_db_name_into_mongo_uri "$NEW_MONGO_URI_VALUE" "wildduck-webmail")
        echo # Adding a newline for better readability of output
        escaped_uri_wildduck=$(printf '%s\n' "$uri_wildduck" | sed 's/&/\\&/g')
        escaped_uri_webmail=$(printf '%s\n' "$uri_webmail" | sed 's/&/\\&/g')

        for config_file_path in "${CONFIG_FILES_TO_UPDATE[@]}"; do
            echo "Processing file: ${config_file_path}"
            
            if [ -f "${config_file_path}" ]; then
                new_config_line=""
                success_msg="Successfully updated MongoDB URI in ${config_file_path}."
                fail_msg="⚠️ Warning: MongoDB URI might not have been updated correctly in ${config_file_path}."
        
                case "${config_file_path}" in
                    *"/wildduck/dbs.toml")
                        # Match: mongo = "mongodb://..."
                        old_config_value='mongo = "mongodb://mongo:27017/wildduck"'
                        new_config_line="mongo = \"$escaped_uri_wildduck\""
                        ;;
                    *"/haraka/wildduck.yaml")
                        # Match: two leading spaces + url: "mongodb://..."
                        old_config_value='  url: "mongodb://mongo:27017/wildduck"'
                        new_config_line="  url: \"$escaped_uri_wildduck\""
                        ;;
                    *"/zone-mta/dbs-development.toml")
                        mongo_uri=$(inject_db_name_into_mongo_uri "$NEW_MONGO_URI_VALUE" "wildduck")
                        escaped_uri=$(printf '%s\n' "$mongo_uri" | sed 's/&/\\&/g')
                        old_config_value='mongo = "mongodb://mongo:27017/zone-mta"'
                        new_config_line="mongo = \"$escaped_uri\""
                        ;;
                    *"/zone-mta/dbs-production.toml")
                        old_config_value='mongo = "mongodb://mongo:27017/wildduck"'
                        new_config_line="mongo = \"$escaped_uri_wildduck\""
                        ;;
                    *"/wildduck-webmail/default.toml")
                        # Match: four leading spaces
                        old_config_value='   mongo="mongodb://mongo:27017/wildduck-webmail"'
                        new_config_line="   mongo=\"$escaped_uri_webmail\""
                        ;;
                    *)
                        echo "  ⚠️ Warning: No specific replacement pattern defined for ${config_file_path}. Skipping."
                        continue
                        ;;
                esac

                sed -i 's,'"$old_config_value"','"$new_config_line"',' "$config_file_path"
                
        
                if grep -qF -- "$NEW_MONGO_URI_VALUE" "$config_file_path"; then
                    echo "  $success_msg"
                else
                    echo "  $fail_msg"
                    echo "    Please check the file manually. The pattern or line structure might differ from assumptions."
                fi
            else
                echo "⚠️ Warning: Configuration file not found: ${config_file_path}. Skipping."
            fi
        
            echo # Newline for readability
        done

    fi
fi

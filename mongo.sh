#!/bin/bash
generate_mongo_uri() {
    local auth_part="" # For constructing the 'username:password@' part

    # Validate that essential variables are set
    if [ -z "${MONGO_HOST}" ]; then
        echo "Error: MONGO_HOST is not set. Cannot generate URI." >&2
        return 1
    fi
    if [ -z "${MONGO_PORT}" ]; then
        echo "Error: MONGO_PORT is not set. Cannot generate URI." >&2
        return 1
    fi
    if [ -z "${MONGO_DB}" ]; then
        echo "Error: MONGO_DB (database name) is not set. Cannot generate URI." >&2
        return 1
    fi

    # Construct the authentication part if MONGO_USER is provided
    if [ -n "${MONGO_USER}" ]; then
        auth_part="${MONGO_USER}"
        if [ -n "${MONGO_PASS}" ]; then
            auth_part="${auth_part}:${MONGO_PASS}"
        fi
        auth_part="${auth_part}@"
    fi

    # Echo the fully constructed URI to standard output
    echo "mongodb://${auth_part}${MONGO_HOST}:${MONGO_PORT}/${MONGO_DB}"
    return 0

}




# Mongo DB
LOCAL_MONGO=true
read -p "Do you wish to use a local MongoDB instance? (Y/n) " yn

    case $yn in
        [Yy]* ) LOCAL_MONGO=true;;
        [Nn]* ) LOCAL_MONGO=false;;
        * ) LOCAL_MONGO=true;;
    esac

if ! $LOCAL_MONGO; then
    # Prompt for MongoDB details (as in your original script)
    read -p "Provide MongoDB URL (mongodb://<db_user>:<db_password>@<db_host>/<db_name>: " MONGO_URL 
  
   
    NEW_MONGO_URI_VALUE=$(MONGO_URL) # Call the function

    if [ -z "${NEW_MONGO_URI_VALUE}" ]; then
        echo "Critical: Failed to generate MongoDB URI. Please check the details provided." >&2
        echo "Skipping update of configuration files due to URI generation failure."
    else
        echo "Generated MongoDB URI: ${NEW_MONGO_URI_VALUE}"

        # --- Define list of configuration files to update ---
        declare -a CONFIG_FILES_TO_UPDATE
        # Using the paths exactly as you provided:
        CONFIG_FILES_TO_UPDATE+=( "/config-generated/config-generated/wildduck/dbs.toml" )
        CONFIG_FILES_TO_UPDATE+=( "/config-generated/config-generated/haraka/wildduck.yaml" )
        CONFIG_FILES_TO_UPDATE+=( "/config-generated/config-generated/zone-mta/dbs-production.toml" )
        CONFIG_FILES_TO_UPDATE+=( "/config-generated/config-generated/wildduck-webmail/default.toml" )

        # Common part of the old URI, regex escaped for sed's pattern matching
        # This matches "mongodb://mongo:27017/wildduck"
        OLD_LOCAL_MONGO_URI_REGEX='mongodb:\/\/mongo:27017\/wildduck'

        echo # Adding a newline for better readability of output

        for config_file_path in "${CONFIG_FILES_TO_UPDATE[@]}"; do
            echo "Processing file: ${config_file_path}"
            if [ -f "${config_file_path}" ]; then
                old_line_pattern=""
                # This is a template for the new line, e.g., "key = \"%s\"" or "key: \"%s\""
                # where %s will be replaced by the NEW_MONGO_URI_VALUE.
                new_line_template=""

                # Determine the specific patterns for each file
                # These are based on common TOML/YAML structures and assumptions.
                # YOU MAY NEED TO ADJUST THESE PATTERNS if the actual lines in your files differ.
                case "${config_file_path}" in
                    *"/wildduck/dbs.toml")
                        old_line_pattern="^\s*mongo\s*=\s*\"${OLD_LOCAL_MONGO_URI_REGEX}\"\s*$"
                        new_line_template="mongo = \"%s\""
                        ;;
                    *"/haraka/wildduck.yaml")
                        # Assuming a simple key: "value" structure for YAML.
                        # Common keys for MongoDB URI in YAML could be 'uri', 'mongo', 'mongo_uri', etc.
                        # ADJUST THE KEY 'uri' IF IT'S DIFFERENT IN YOUR haraka/wildduck.yaml
                        old_line_pattern="^\s*uri:\s*\"${OLD_LOCAL_MONGO_URI_REGEX}\"\s*$"
                        new_line_template="uri: \"%s\""
                        ;;
                    *"/zone-mta/dbs-production.toml")
                        # Assuming the key is 'uri' in zone-mta's dbs-production.toml. ADJUST IF NEEDED.
                        old_line_pattern="^\s*uri\s*=\s*\"${OLD_LOCAL_MONGO_URI_REGEX}\"\s*$"
                        new_line_template="uri = \"%s\""
                        ;;
                    *"/wildduck-webmail/default.toml")
                        # Assuming the key is 'mongo' in wildduck-webmail's default.toml. ADJUST IF NEEDED.
                        old_line_pattern="^\s*mongo\s*=\s*\"${OLD_LOCAL_MONGO_URI_REGEX}\"\s*$"
                        new_line_template="mongo = \"%s\""
                        ;;
                    *)
                        echo "  Warning: No specific replacement pattern defined for ${config_file_path}. Skipping."
                        continue # Skip to the next file
                        ;;
                esac

                # Construct the actual new line using the template and the new URI
                # printf is used to safely insert the URI into the template string.
                new_config_line=$(printf "${new_line_template}" "${NEW_MONGO_URI_VALUE}")

                echo "  Attempting to replace lines matching regex: ${old_line_pattern}"
                echo "  With the new line: ${new_config_line}"
                
                # Perform the replacement using sed. Using '|' as a delimiter.
                # The -i '' is for BSD/macOS sed (in-place edit, no backup).
                # For GNU sed, you might use -i (which creates a backup if no extension given) or -i.bak
                sed -i '' "s|${old_line_pattern}|${new_config_line}|" "${config_file_path}"

                # Verify if the update was successful
                if grep -qF -- "${new_config_line}" "${config_file_path}"; then
                    echo "  Successfully updated MongoDB URI in ${config_file_path}."
                else
                    echo "  ⚠️ Warning: MongoDB URI might not have been updated correctly in ${config_file_path}."
                    echo "     Please check the file manually. The pattern or line structure might differ from assumptions."
                fi
            else
                echo "Warning: Configuration file not found: ${config_file_path}. Skipping."
            fi
            echo # Adding a newline for better readability of output between files
        done
    # else # This would be the block for if $LOCAL_MONGO is true (URI generation failed)
        # echo "Skipping configuration file updates."
    fi
# else # This would be the block for if $LOCAL_MONGO is true
    # echo "Retaining local MongoDB configuration in all files."
fi

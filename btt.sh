#!/bin/bash
######################################################################################
## PROGRAM   : btt.sh
## PROGRAMER : Brett Collingwood
## EMAIL-1   : brett@amperecomputing.com
## EMAIL-2   : brett.a.collingwood@gmail.com
## MUSE      : Kit
## VERSION   : 1.0.0
## DATE      : 2026-02-27
## PURPOSE   : A batch testing tool to erase, move, execute, and log file operations.
## #---------------------------------------------------------------------------------#
## THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
## INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
## PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
## HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
## OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
## SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
######################################################################################

# ------------------------------------------------------------------------------------
# User Configuration Variables
# Edit these to change the script's behavior
# ------------------------------------------------------------------------------------
MOVE_SRC_PATTERN="/tmp/test_data_*.txt" # Files to move from /tmp
MOVE_DEST_DIR="/tmp/btt_target"        # Destination directory for the moved files
EXEC_CMD="echo 'Running test command...'" # Command to execute inside MOVE_DEST_DIR
CAT_LOG_PATTERN="*.log"                # Pattern of log files to cat inside MOVE_DEST_DIR
# ------------------------------------------------------------------------------------

# Script Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$SCRIPT_DIR/log"
LOG_FILE="$LOG_DIR/btt.log"

# Create log directory
mkdir -p "$LOG_DIR"
chown "${SUDO_USER:-$USER}:$(id -g "${SUDO_USER:-$USER}")" "$LOG_DIR" 2>/dev/null || true

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ------------------------------------------------------------------------------------
# Helper Functions
# ------------------------------------------------------------------------------------

log() {
    local message="$1"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    # Print to screen with colors
    echo -e "${timestamp} - ${message}"
    # Strip non-printable characters (ANSI, etc.) for log file
    echo -e "${timestamp} - ${message}" | sed 's/\x1b\[[0-9;]*m//g' | tr -cd '\11\12\40-\176' >> "$LOG_FILE"
}

handle_error() {
    local message="$1"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo -e "${RED}${timestamp} - [ERROR] ${message}${NC}"
    echo "${timestamp} - [ERROR] ${message}" >> "$LOG_FILE"
    log "Pausing for 5 seconds..."
    sleep 5
}

# ------------------------------------------------------------------------------------
# Main Execution
# ------------------------------------------------------------------------------------

# Initialize log file with correct ownership
touch "$LOG_FILE"
chown "${SUDO_USER:-$USER}:$(id -g "${SUDO_USER:-$USER}")" "$LOG_FILE" 2>/dev/null || true

log "----------------------------------------"
log "Starting btt v1.0.0"
log "----------------------------------------"

# 1. Move Files
if [ -n "$MOVE_DEST_DIR" ] && [ -n "$MOVE_SRC_PATTERN" ]; then
    log "Phase 1: Moving files matching '$MOVE_SRC_PATTERN' to $MOVE_DEST_DIR"
    
    # Create directory if it doesn't exist
    if [ ! -d "$MOVE_DEST_DIR" ]; then
        mkdir -p "$MOVE_DEST_DIR" 2>> "$LOG_FILE" || handle_error "Failed to create directory $MOVE_DEST_DIR"
        log "Created directory $MOVE_DEST_DIR"
    fi

    # Check if files matching the pattern exist before moving
    if ls $MOVE_SRC_PATTERN >/dev/null 2>&1; then
        mv $MOVE_SRC_PATTERN "$MOVE_DEST_DIR/" 2>> "$LOG_FILE" || handle_error "Failed to move files."
        log "${GREEN}Successfully moved files.${NC}"
    else
        log "${YELLOW}No files found matching pattern: $MOVE_SRC_PATTERN${NC}"
    fi
else
    log "${YELLOW}MOVE variables are empty. Skipping move phase.${NC}"
fi

# 2. Execute Command
if [ -n "$EXEC_CMD" ]; then
    log "Phase 2: Executing command in $MOVE_DEST_DIR"
    if [ -d "$MOVE_DEST_DIR" ]; then
        cd "$MOVE_DEST_DIR" || handle_error "Failed to cd into $MOVE_DEST_DIR"
        log "Running: $EXEC_CMD"
        # Execute the command and capture both stdout and stderr to the log file
        eval "$EXEC_CMD" 2>&1 | while read -r line; do log "  > $line"; done
        # Check if the command itself failed (eval PIPESTATUS[0] captures the eval exit code, not the while loop's)
        if [ ${PIPESTATUS[0]} -ne 0 ]; then
            handle_error "Command execution failed."
        else
            log "${GREEN}Command executed successfully.${NC}"
        fi
    else
        handle_error "Cannot execute command. Directory $MOVE_DEST_DIR does not exist."
    fi
else
    log "${YELLOW}EXEC_CMD variable is empty. Skipping execute phase.${NC}"
fi

# 3. Cat Log Files
if [ -n "$CAT_LOG_PATTERN" ]; then
    log "Phase 3: Catting log files matching '$CAT_LOG_PATTERN' in $MOVE_DEST_DIR"
    if [ -d "$MOVE_DEST_DIR" ]; then
        cd "$MOVE_DEST_DIR" || handle_error "Failed to cd into $MOVE_DEST_DIR"
        
        # Expand the wildcard to see if files exist
        has_logs=false
        for file in $CAT_LOG_PATTERN; do
            if [ -f "$file" ]; then
                has_logs=true
                log "--- Contents of $file ---"
                cat "$file" 2>&1 | while read -r line; do log "    $line"; done
                log "-------------------------"
            fi
        done
        
        if [ "$has_logs" = false ]; then
            log "${YELLOW}No files found matching pattern: $CAT_LOG_PATTERN${NC}"
        fi
    else
         handle_error "Cannot cat logs. Directory $MOVE_DEST_DIR does not exist."
    fi
else
    log "${YELLOW}CAT_LOG_PATTERN variable is empty. Skipping cat logs phase.${NC}"
fi

log "----------------------------------------"
log "Process complete."
log "Log saved to: $LOG_FILE"
log "----------------------------------------"
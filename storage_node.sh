#!/bin/bash

show_menu() {
    echo "===== Zstake Storage Node Installation Menu ====="
    echo "1. Install 0g-storage-node"
    echo "2. Update 0g-storage-node"
    echo "3. Turbo Mode(Reset Config.toml & Systemctl)"
    echo "4. Standard Mode(Reset Config.toml & Systemctl)"
    echo "5. Select RPC Endpoint"
    echo "6. Set Miner Key"
    echo "7. Node Run & Show Logs"
    echo "8. Install Snapshot"
    echo "9. Install Second 0g-storage-node"
    echo "10. Manage Second Node"
    echo "11. Exit"
    echo "============================"
}

install_node() {
    echo "Installing 0g-storage-node..."
    rm -r $HOME/0g-storage-node
    sudo apt-get update
    sudo apt-get install -y cargo git clang cmake build-essential openssl pkg-config libssl-dev
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source $HOME/.cargo/env
    git clone -b v0.8.7 https://github.com/0glabs/0g-storage-node.git
    cd $HOME/0g-storage-node
    git stash
    git fetch --all --tags
    git checkout 74074df
    git submodule update --init
    cargo build --release
    rm -rf $HOME/0g-storage-node/run/config.toml
    curl -o $HOME/0g-storage-node/run/config.toml https://raw.githubusercontent.com/zstake-xyz/test/refs/heads/main/0g_storage_turbo.toml
    sudo tee /etc/systemd/system/zgs.service > /dev/null <<EOF
[Unit]
Description=ZGS Node
After=network.target

[Service]
User=$USER
WorkingDirectory=$HOME/0g-storage-node/run
ExecStart=$HOME/0g-storage-node/target/release/zgs_node --config $HOME/0g-storage-node/run/config.toml
Restart=on-failure
RestartSec=10
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload
    sudo systemctl enable zgs
    echo "Installation completed. You can start the service with 'sudo systemctl start zgs'."
}

update_node() {
    echo "Updating 0g-storage-node..."
    sudo systemctl stop zgs
    cp $HOME/0g-storage-node/run/config.toml $HOME/0g-storage-node/run/config.toml.backup
    cd $HOME/0g-storage-node
    git stash
    git fetch --all --tags
    git checkout 74074df
    git submodule update --init
    cargo build --release
    cp $HOME/0g-storage-node/run/config.toml.backup $HOME/0g-storage-node/run/config.toml
    sudo systemctl daemon-reload
    sudo systemctl enable zgs
    sudo systemctl start zgs
    echo "Node update completed."
}

reset_config_systemctl() {
    echo "Resetting Config.toml and Systemctl (Turbo Mode)..."
    rm -rf $HOME/0g-storage-node/run/config.toml
    curl -o $HOME/0g-storage-node/run/config.toml https://raw.githubusercontent.com/zstake-xyz/test/refs/heads/main/0g_storage_turbo.toml
    sudo tee /etc/systemd/system/zgs.service > /dev/null <<EOF
[Unit]
Description=ZGS Node
After=network.target

[Service]
User=$USER
WorkingDirectory=$HOME/0g-storage-node/run
ExecStart=$HOME/0g-storage-node/target/release/zgs_node --config $HOME/0g-storage-node/run/config.toml
Restart=on-failure
RestartSec=10
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload
    sudo systemctl enable zgs
    echo "Config.toml and Systemctl have been reset to Turbo Mode. You can start the service with 'sudo systemctl start zgs'."
}

standard_mode_reset() {
    echo "Resetting to Standard Mode..."
    rm -rf $HOME/0g-storage-node/run/config.toml
    curl -o $HOME/0g-storage-node/run/config.toml https://raw.githubusercontent.com/zstake-xyz/test/refs/heads/main/0g_storage_config.toml
    nano $HOME/0g-storage-node/run/config.toml
    echo "Config.toml has been reset to Standard Mode and opened for editing. Please save your changes in nano (Ctrl+O, Enter, Ctrl+X)."
}

select_rpc() {
    echo "Select an RPC Endpoint:"
    echo "1. https://evmrpc-testnet.0g.ai"
    echo "2. https://16600.rpc.thirdweb.com"
    echo "3. https://og-testnet-evm.itrocket.net:443"
    read -p "Enter your choice (1-3): " rpc_choice
    case $rpc_choice in
        1) rpc="https://evmrpc-testnet.0g.ai" ;;
        2) rpc="https://16600.rpc.thirdweb.com" ;;
        3) rpc="https://og-testnet-evm.itrocket.net:443" ;;
        *) echo "Invalid choice. Exiting."; return ;;
    esac
    sed -i "s|^blockchain_rpc_endpoint = .*|blockchain_rpc_endpoint = \"$rpc\"|g" ~/0g-storage-node/run/config.toml
    sudo systemctl stop zgs
    sudo systemctl daemon-reload
    sudo systemctl enable zgs
    echo "RPC Endpoint set to $rpc. You can start the service with 'sudo systemctl start zgs'."
}

set_miner_key() {
    echo "Please enter your Miner Key:"
    read miner_key
    sed -i "s|^miner_key = .*|miner_key = \"$miner_key\"|g" ~/0g-storage-node/run/config.toml
    sudo systemctl daemon-reload
    sudo systemctl enable zgs
    sudo systemctl stop zgs
    sudo systemctl daemon-reload
    sudo systemctl enable zgs
    echo "Miner Key updated. You can start the service with 'sudo systemctl start zgs'."
}

show_logs() {
    echo "Displaying logs..."
    sudo systemctl daemon-reload && sudo systemctl enable zgs && sudo systemctl start zgs
    tail -f ~/0g-storage-node/run/log/zgs.log.$(TZ=UTC date +%Y-%m-%d)
}

install_snapshot() {
    echo "Installing snapshot..."
    
    # 1. Stop Storage node
    echo "Stopping ZGS service..."
    sudo systemctl stop zgs
    
    # 2. Install required tools
    echo "Installing required tools..."
    sudo apt-get update
    sudo apt-get install wget lz4 aria2 pv -y
    
    # 3. Download snapshot
    echo "Downloading snapshot (LogSyncHeight 3748425 | Size: 8.0G)..."
    cd $HOME
    rm -f storage_0gchain_snapshot.lz4
    aria2c -x 16 -s 16 -k 1M https://josephtran.co/storage_0gchain_snapshot.lz4
    
    # 4. Extract data
    echo "Extracting data..."
    rm -rf $HOME/0g-storage-node/run/db
    lz4 -c -d storage_0gchain_snapshot.lz4 | pv | tar -x -C $HOME/0g-storage-node/run
    
    # 5. Restart node
    echo "Restarting node and showing logs..."
    sudo systemctl restart zgs && tail -f ~/0g-storage-node/run/log/zgs.log.$(TZ=UTC date +%Y-%m-%d)
}

install_second_node() {
    echo "Installing second 0g-storage-node..."
    # Create a different directory for the second node
    rm -r $HOME/0g-storage-node2
    sudo apt-get update
    sudo apt-get install -y cargo git clang cmake build-essential openssl pkg-config libssl-dev
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source $HOME/.cargo/env
    git clone -b v0.8.7 https://github.com/0glabs/0g-storage-node.git $HOME/0g-storage-node2
    cd $HOME/0g-storage-node2
    git stash
    git fetch --all --tags
    git checkout 74074df
    git submodule update --init
    cargo build --release
    
    # Create run directory and config if they don't exist
    mkdir -p $HOME/0g-storage-node2/run
    rm -rf $HOME/0g-storage-node2/run/config.toml
    curl -o $HOME/0g-storage-node2/run/config.toml https://raw.githubusercontent.com/zstake-xyz/test/refs/heads/main/0g_storage_turbo.toml
    
    # Use a different port for the second node
    sed -i 's/port = 44444/port = 44445/g' $HOME/0g-storage-node2/run/config.toml
    sed -i 's/metrics_port = 14444/metrics_port = 14445/g' $HOME/0g-storage-node2/run/config.toml

    # Ask for second node miner key
    echo "Please enter your Miner Key for the second node:"
    read miner_key2
    sed -i "s|^miner_key = .*|miner_key = \"$miner_key2\"|g" $HOME/0g-storage-node2/run/config.toml
    
    # Create a different systemd service for the second node
    sudo tee /etc/systemd/system/zgs2.service > /dev/null <<EOF
[Unit]
Description=ZGS Node 2
After=network.target

[Service]
User=$USER
WorkingDirectory=$HOME/0g-storage-node2/run
ExecStart=$HOME/0g-storage-node2/target/release/zgs_node --config $HOME/0g-storage-node2/run/config.toml
Restart=on-failure
RestartSec=10
LimitNOFILE=65535

[Install]
WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload
    sudo systemctl enable zgs2
    echo "Second node installation completed. You can start the service with 'sudo systemctl start zgs2'."
}

manage_second_node() {
    echo "===== Second Node Management ====="
    echo "1. Start second node"
    echo "2. Stop second node"
    echo "3. Show second node logs"
    echo "4. Install snapshot for second node"
    echo "5. Update second node"
    echo "6. Set Miner Key for second node"
    echo "7. Back to main menu"
    
    read -p "Select an option (1-7): " second_node_choice
    case $second_node_choice in
        1) 
            echo "Starting second node..."
            sudo systemctl start zgs2
            ;;
        2) 
            echo "Stopping second node..."
            sudo systemctl stop zgs2
            ;;
        3) 
            echo "Displaying second node logs..."
            tail -f ~/0g-storage-node2/run/log/zgs.log.$(TZ=UTC date +%Y-%m-%d)
            ;;
        4) 
            echo "Installing snapshot for second node..."
            sudo systemctl stop zgs2
            sudo apt-get install wget lz4 aria2 pv -y
            cd $HOME
            rm -f storage_0gchain_snapshot2.lz4
            aria2c -x 16 -s 16 -k 1M https://josephtran.co/storage_0gchain_snapshot.lz4 -o storage_0gchain_snapshot2.lz4
            rm -rf $HOME/0g-storage-node2/run/db
            lz4 -c -d storage_0gchain_snapshot2.lz4 | pv | tar -x -C $HOME/0g-storage-node2/run
            sudo systemctl restart zgs2
            ;;
        5) 
            echo "Updating second node..."
            sudo systemctl stop zgs2
            cp $HOME/0g-storage-node2/run/config.toml $HOME/0g-storage-node2/run/config.toml.backup
            cd $HOME/0g-storage-node2
            git stash
            git fetch --all --tags
            git checkout 74074df
            git submodule update --init
            cargo build --release
            cp $HOME/0g-storage-node2/run/config.toml.backup $HOME/0g-storage-node2/run/config.toml
            sudo systemctl daemon-reload
            sudo systemctl enable zgs2
            sudo systemctl start zgs2
            ;;
        6)
            echo "Please enter your Miner Key for the second node:"
            read miner_key2
            sed -i "s|^miner_key = .*|miner_key = \"$miner_key2\"|g" $HOME/0g-storage-node2/run/config.toml
            sudo systemctl restart zgs2
            ;;
        7) return ;;
        *) echo "Invalid option. Please try again." ;;
    esac
}

while true; do
    show_menu
    read -p "Select an option (1-11): " choice
    case $choice in
        1) install_node ;;
        2) update_node ;;
        3) reset_config_systemctl ;;
        4) standard_mode_reset ;;
        5) select_rpc ;;
        6) set_miner_key ;;
        7) show_logs ;;
        8) install_snapshot ;;
        9) install_second_node ;;
        10) manage_second_node ;;
        11) echo "Exiting..."; exit 0 ;;
        *) echo "Invalid option. Please try again." ;;
    esac
    echo ""
done

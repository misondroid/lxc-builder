# lxc-builder
Ubuntubの[LXC(LinuX Container: Linuxコンテナ)](https://www.docker.com/ja-jp/blog/lxc-vs-docker/)のテンプレートイメージを作成するスクリプト一式です。
AMD64用はProxmoxのGUIから拾い放題なのですが、ARM64用はほので自作しようと思ってAIさんたちとコネ杭回した結果をまとめます。

## ファイル構成
 - build.sh: 各工程の処理結果をLXCテンプレートにまとめます。
   - scripts/ 各処理工程のスクリプトをまとめています。
     - bootstrap.sh: 基本になるrootfsを作成します。
     - configure.sh: 作成したrootfsに最低限の設定を行います。
     - cleanup.sh: 最低限の設定のうち、システム固有になる設定を除去します。
   - dist/ 作成されたテンプレートイメージが保管されます。
   - work/ rootfsを配置して諸々の操作を行います。

## 使い方（Poxmox）
- 私はProxmoxでLXCを使いたかったので、本稿ではProxmoxでの使い方を書きます。
  - ビルド作業を行ったのはaspbeyy Pi 4 + Proxmox VE 9.2 の上に作業用に構築したUbuntu26.04LTSのVMです。
  - Intel x64でも利用可能のはずですが、QEmuでのARM64エミュレーション下では未検証です。ラズパイやApple SiliconなMacでご利用いただいたほうが無難かと思います。

以下、本リポジトリをCloneしたディレクトリ内での作業となります。ビルドホストとProxmoxホストで実行するコマンドがあるので、コードブロックを別々に書くようにしますが、以下のように明示的に書いています。
```bash
(build) $ #ビルドホストで実行するコマンド
(poxmox) $ #Poxmoxホスト側で実行するコマンド  
```
Proxmox側は基本的に`root`での操作になるので、プロンプトは`#`になるのですが、一般ユーザーから`sudo`越しにやってるのはあくまで好みというか習慣というか宗教上の問題なので、あまり気にしないでください。
### 1. テンプレートの作成  
```bash
# ビルドホストでの作業
$ ./build.sh SUITE={バージョン名} ARCH={アーキテクチャ}
# バージョン名:
# resolute: 26.04(デフォルト)
# noble: 24.04
# アーキテクチャ:
# arm64: ARM
# amd64: Intel-x64
```
### 2. Poxmoxへの登録
scpとかでテンプレート用のストレージに突っ込めばOKです。
Web UIからアップロードすることもできますが、こっちのが手っ取り早いです。

``` bash
##### ビルドホストでの作業（転送）
(build) $ scp dist/ubuntu-26.04-minimal_RM64.tar.zst proxmox:/tmp
```
``` bash
#### Proxmoxホストでの作業
# 例ではデフォルトストレージにつっこんでます。
(proxmox) $ sudo cp /tmp/ /var/lib/vz/template/cache/
(proxmox) $ sudo pveam list local
NAME                                                         SIZE  
local:vztmpl/ubuntu-24.04-minimal_arm64.tar.zst              67.33MB
# 登録が成功していたらここで出てきます。もちろんWebUIからでも確認できます。
```

### 3. Proxmox上でのコンテナ作成
CLIからやってもいいですが、ここはWebUIのが楽かな、と思います。
```bash
#### Proxmoxホストでの作業
#### 割り当て可能なVMIDを確認
# 下記の例ではVVMID100とVMID101でそれぞれVMとLXCが起動しているので、
# 102移行が利用可能、と判定できる
(proxmox) $ sudo qm list
      VMID NAME                 STATUS     MEM(MB)    BOOTDISK(GB) PID       
       100 gateway2             running    4096              32.00 6452      
(proxmox) $ sudo pct list
VMID       Status     Lock         Name                
101        running                 ubuntu-arm64-test    
#### LXCを起動
(proxmox) $ sudo pct create {先ほど確認した利用可能なVMID} \
    local:vztmpl/ubuntu-26.04-minimal_arm64.tar.zst \
    --arch {アーキテクチャ} \
    --ostype ubuntu \
    --hostname {つけたいコンテナ名} \ 
    --rootfs {割当先ストレージ名}:{割り当てストレージ容量(GB単位)} \ 
    --memory {割り当てメモリ(MB単位)} \
    --swap {割り当てスワップメモリ(MB単位)} \
    --cores {割り当てvCPUコア数} \
    --net0 {NIC #0の設定（後述） 例: name=eth0,bridge=vmbr0,ip=dhcp } \
    --unprivileged {1:特権コンテナ化 / 0:通常起動}

#### `--netX`の各種オプション
#  - name={コンテナから見えるアダプタのデバイス名 例:eth0}
#  - bridgge={Proxmox側からアタッチするブリッジ／ネットワーク 例:vmbr0}
#  - ip={アタッチするIP `dhcp`にしたらDHCPになります}
```
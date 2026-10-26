# lxc-builder
LXC(Light-weighted linuX Container: 軽量Linuxコンテナ)のテンプレートイメージを作成するスクリプト一式です。
AMD64用はProxmoxのGUIから拾い放題なのですが、ARM64用はほので自作

## ファイル構成
 - build.sh: 各工程の処理結果をLXCテンプレートにまとめます。
   - scripts/ 各処理工程のスクリプトをまとめています。
     - bootstrap.sh: 基本になるrootfsを作成します。
     - configure.sh: 作成したrootfsに最低限の設定を行います。
     - cleanup.sh: 最低限の設定のうち、システム固有になる設定を除去します。
   - dist/ 作成されたテンプレートイメージが保管されます。
   - work/ rootfsを配置して諸々の操作を行います。

## 使い方  
```bash
$ ./build.sh

#現状はnoble(Debian12/Ubuntu24.04LTS相当)専用ですが、26.04等別のスイートが出てきたら対応予定です。
```
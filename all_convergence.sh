# コマンドライン引数から.vaspファイルのパスを取得
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <VASP_FILE_PATH>"
    exit 1
fi
FILE_REL_PATH="$1"
RELAX="YES"  # YES, or NO. Relax引数がなければ、デフォルトで'NO'を使用

# パスを絶対パスに変換する
FILE_PATH=$(realpath "$FILE_REL_PATH")

# working dirctoryを作ってそこで作業を行う。なお、そのディレクトリに存在したファイルなどは削除する
WORK_DIR="workspace__"
WORK_DIR="$WORK_DIR""$(basename "$FILE_PATH")"
mkdir -p $WORK_DIR
rm -rf $WORK_DIR/*

# 必要なファイルをコピー
cp create_vasp_inputs.py create_run_vasp_file.sh ./$WORK_DIR
cp $FILE_REL_PATH ./$WORK_DIR/POSCAR
cd $WORK_DIR

# VASPの入力ファイルなどを作成
python create_vasp_inputs.py POSCAR
cp ../calculate_bandgap.py ./bandgap_cal
sh create_run_vasp_file.sh $FILE_PATH $RELAX

# VASP計算を実行
qsub run_vasp.sh

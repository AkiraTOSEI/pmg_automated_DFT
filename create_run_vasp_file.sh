if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <VASP_FILE_PATH> $1 <RELAX>,"
    exit 1
fi

FILE_PATH="$1"
RELAX="$2"

FILE_NAME=$(basename "$FILE_PATH")

cat > run_vasp.sh <<EOF
#!/bin/sh
#PBS -l nodes=1:ppn=16
#PBS -N $FILE_NAME
cd \$PBS_O_WORKDIR
export I_MPI_COMPATIBILITY=4
NPROCS=\$(cat \$PBS_NODEFILE | wc -l)

#!/bin/bash

# 処理開始時刻を取得
start=\$(date +%s)



date
EOF

if [ "$RELAX" = "YES" ];  then
    echo "###############  Relaxation  ###############" >> run_vasp.sh
    echo "echo '###############  Relaxation  ###############' " >> run_vasp.sh
    echo "cd relaxed" >> run_vasp.sh
    echo "mpiexec -iface ib0 -launcher rsh -machinefile \$PBS_NODEFILE -ppn 16 /home/share/VASP/vasp.5.4.4" >> run_vasp.sh
    echo "cp CONTCAR ../final_scf/POSCAR" >> run_vasp.sh
    echo "cp CONTCAR ../bandgap_cal/POSCAR" >> run_vasp.sh
    echo "cd ../" >> run_vasp.sh
    echo "###############" >> run_vasp.sh

elif [ "$RELAX" = "NO" ];  then
    echo "############### No Relaxation"  >> run_vasp.sh
    echo "echo '############### No Relaxation' " >> run_vasp.sh
    echo "cp relaxed/POSCAR ./final_scf" >> run_vasp.sh
    echo "cp relaxed/POSCAR ./bandgap_cal/" >> run_vasp.sh
else
    echo "Error: Invalid argument - $RELAX"
    exit 2
fi


cat >> run_vasp.sh <<EOF
###############  Final SCF  ###############
echo '###############  Final SCF  ###############'
cd final_scf
mpiexec -iface ib0 -launcher rsh -machinefile \$PBS_NODEFILE -ppn 16 /home/share/VASP/vasp.5.4.4
cp CHGCAR ../bandgap_cal
date

###############  Bandgap Calculation  ###############
echo '###############  Bandgap Calculation  ###############'
cd ../bandgap_cal
mpiexec -iface ib0 -launcher rsh -machinefile \$PBS_NODEFILE -ppn 16 /home/share/VASP/vasp.5.4.4
date


echo "#######################################"
echo "###            VASP ends!           ###"
echo "#######################################"

cp OUTCAR ../final_OUTCAR
cp DOSCAR ../final_DOSCAR
cp POSCAR ../final_POSCAR
cp KPOINTS ../final_KPOINTS
cp INCAR ../final_INCAR
cp vasprun.xml ../


# 圧力 (kB)をOUTCARから得る
pressure=\$(grep "external pressure" OUTCAR | awk '{print \$4}')


### バンドギャップ計算用のDOSCARを作成する
# 最初の8行をスキップし、4列以上のデータを含む行を無視
tail -n +9 DOSCAR | awk 'NF <= 5 { print }' > tmp_DOSCAR

E_fermi=\$(grep "E-fermi" ../final_OUTCAR | awk '{print \$3}')
OUTPUT_FILE="../../bandgap_result.csv"

echo "E_fermi: \$E_fermi"
echo "pressure: \$pressure (kB)"

### E-fermiの値が計算できたかどうかでダミーの値をいれるかどうかを判定する
if [ -z "\$E_fermi"]; then
    # outputが存在するかどうかをチェック
    if [ -e \$OUTPUT_FILE ]; then
        # ファイルが存在する場合、通常のlsの結果をファイルに出力
        echo "$FILE_PATH , -1, False. -1" >> \$OUTPUT_FILE
    else
        # ファイルが存在しない場合、隠しファイルを含むls -aの結果をファイルに出力
        echo 'file_name, bandgap(eV), nonmetal, pressure(GPa)' > \$OUTPUT_FILE
        echo "$FILE_PATH , -1, False, -1" >> \$OUTPUT_FILE
    fi
else
    # outputが存在するかどうかをチェック
    if [ -e \$OUTPUT_FILE ]; then
        # ファイルが存在する場合、通常のlsの結果をファイルに出力
        python calculate_bandgap.py -f \$E_fermi -pr \$pressure -ps $FILE_PATH >> \$OUTPUT_FILE
    else
        # ファイルが存在しない場合、隠しファイルを含むls -aの結果をファイルに出力
        echo 'file_name, bandgap(eV), nonmetal, pressure(GPa)' > \$OUTPUT_FILE
        python calculate_bandgap.py -f \$E_fermi -pr \$pressure -ps $FILE_PATH >> \$OUTPUT_FILE
    fi
fi

echo "#######################################"
echo "###     bandgap cpp ends!           ###"
echo "#######################################"

cd ../

# 処理終了時刻を取得
end=\$(date +%s)

# 処理にかかった時間を計算
duration=\$((end - start))

# 時間・分・秒に変換
hours=\$((duration / 3600))
minutes=\$(( (duration % 3600) / 60 ))
seconds=\$((duration % 60))

echo "処理時間: \${hours}時間 \${minutes}分 \${seconds}秒"

# 特定のファイル以外を削除
#rm -rf bandgap_cal final_scf relaxed
#shopt -s extglob
#rm -f !(POSCAR_gt|POSCAR_distorted|final_INCAR|final_KPOINTS|final_OUTCAR|final_DOSCAR|final_POSCAR|used_POTCAR.txt|kp_history.dat|encut_history.dat)

date
EOF

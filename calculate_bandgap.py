import pandas as pd
import numpy as np
import argparse

def read_fermi_energy(file_path):
    # Placeholder for the code to read Fermi energy from the file
    with open(file_path, 'r') as file:
        data = file.read()  # This is a simplification; you would extract the Fermi energy here
    return float(data.strip())  # Assuming Fermi energy is the only content for simplification


def analyze_dos(e_fermi=None, Pressure=None, POSCAR_path=""):
    if e_fermi is None or Pressure is None or POSCAR_path == "":
        raise ValueError("Fermi energy, Pressure, and POSCAR path must be provided.")
    
    Pressure = float(Pressure)
    
    # Load data
    dos = pd.read_csv('tmp_DOSCAR', delim_whitespace=True, header=None)
    dos = dos.rename(columns={0: 'Energy', 1: 'DOS(UP)', 2: 'DOS(DOWN)', 3: 'Integ_DOS(UP)', 4: 'Integ_DOS(DOWN)'})

    # Remove data below the Fermi level
    energy_step = dos.loc[1,'Energy'] - dos.loc[0,'Energy']
    dos['Almost_AboveEf'] = (dos['Energy'] - e_fermi + energy_step*3)>0
    dos = dos[dos['Almost_AboveEf']].reset_index(drop=True)

    # Find the zero states and their index
    dos['zero_states'] = (dos['DOS(UP)'] == 0) & (dos['DOS(DOWN)'] == 0)
    zero_states_index = dos[dos['zero_states']].index.to_list()

    # get the index of the first zero state
    VBM_index = min(zero_states_index)-1

    if not np.abs(dos.loc[VBM_index,'Energy'] - e_fermi) < energy_step*2:
        band_gap, non_metal = 0, False

    else:
        # get Conduction band minimum index
        sequence_index = np.arange(len(zero_states_index)) + VBM_index+1
        CBM_index = min(np.array(sequence_index )[sequence_index != zero_states_index])

        # check if the zero states are in the range of VBM and CBM
        assert (dos.loc[VBM_index+1:CBM_index-1, 'zero_states'] == True).all() # check if the zero states are in the range of VBM and CBM
        assert (not dos.loc[VBM_index, 'zero_states']) and (not dos.loc[CBM_index, 'zero_states']) # check if the VBM and CBM are zero states
        assert dos.loc[VBM_index, 'DOS(UP)'] > 0 and dos.loc[CBM_index, 'DOS(UP)'] > 0 # check if the VBM and CBM are not zero states
        assert dos.loc[VBM_index, 'DOS(DOWN)'] > 0 and dos.loc[CBM_index, 'DOS(DOWN)'] > 0 # check if the VBM and CBM are not zero states
        band_gap = dos.loc[CBM_index, 'Energy'] - dos.loc[VBM_index, 'Energy']
        non_metal = True
    
        print(POSCAR_path ,f', {band_gap:.3f}, {non_metal}, {(Pressure/10):.3f}') # Pressure is in kilo bar, convert to GPa

def main():
    parser = argparse.ArgumentParser(description="Analyze DOS data for band gaps.")
    parser.add_argument("-f", "--fermi", type=float, required=True, help="Fermi energy level")
    parser.add_argument("-pr", "--Pressure", type=str, required=True, help="Pressure")
    parser.add_argument("-ps", "--POSCAR", type=str, required=True, help="POSCAR path")
    
    args = parser.parse_args()
    analyze_dos(args.fermi, args.Pressure, args.POSCAR)

if __name__ == "__main__":
    main()

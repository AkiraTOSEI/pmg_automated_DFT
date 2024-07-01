import os
import copy
from pymatgen.core import Structure
from pymatgen.io.vasp.sets import MPRelaxSet
import pymatgen.io.vasp.inputs as pgi
import sys

def main(poscar_path):
    relax_dir = 'relaxed'
    final_scf_dir = 'final_scf'
    bandgap_dir = 'bandgap_cal'
    os.makedirs(relax_dir, exist_ok=True)
    os.makedirs(final_scf_dir, exist_ok=True)
    os.makedirs(bandgap_dir, exist_ok=True)

    s = Structure.from_file(poscar_path)
    # INCAR
    vasp_set = MPRelaxSet(s)
    relax_incar = vasp_set.incar    
    relax_incar.write_file(os.path.join(relax_dir,"INCAR"))
    ## INCAR for final scf
    scf_incar = copy.deepcopy(relax_incar)
    scf_incar.pop('IBRION', None)
    scf_incar.pop('NSW',None)
    scf_incar.pop('ISIF',None)
    scf_incar.pop('EDIFFG',None)
    scf_incar.write_file(os.path.join(final_scf_dir,"INCAR"))
    ## INCAR for DOS
    bandgap_incar = copy.deepcopy(scf_incar)
    bandgap_incar['NEDOS'] = 2000
    bandgap_incar['ICHARG'] = 11
    bandgap_incar.write_file(os.path.join(bandgap_dir,"INCAR"))

    # KPOINTS
    vasp_set.kpoints.write_file(os.path.join(relax_dir,"KPOINTS"))
    vasp_set.kpoints.write_file(os.path.join(final_scf_dir,"KPOINTS"))
    vasp_set.kpoints.write_file(os.path.join(bandgap_dir,"KPOINTS"))

    # POSCAR
    vasp_set.poscar.write_file(os.path.join(relax_dir,"POSCAR"))

    # POTCAR
    potcar_symbols, spcieces = [], set()
    for site in MPRelaxSet(s).poscar.as_dict()['structure']['sites']:
        spcieces.add(site['species'][0]['element'])
        atom = site['label']
        pot_sym = vasp_set.config_dict['POTCAR'][atom]
        if not pot_sym in potcar_symbols:
            potcar_symbols.append(vasp_set.config_dict['POTCAR'][atom])
    assert len(spcieces) == len(potcar_symbols)
    potcar = pgi.Potcar(symbols=potcar_symbols,functional='PBE_54')
    potcar.write_file(os.path.join(relax_dir,"POTCAR"))
    potcar.write_file(os.path.join(final_scf_dir,"POTCAR"))
    potcar.write_file(os.path.join(bandgap_dir,"POTCAR"))

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python script.py <path_to_POSCAR>")
        sys.exit(1)
    poscar_path = sys.argv[1]
    main(poscar_path)

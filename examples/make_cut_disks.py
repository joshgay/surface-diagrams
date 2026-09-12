from pathlib import Path
from surface_diagrams import save_svg
from surface_diagrams.standard_cuts import chain_system
from surface_diagrams.disk_routes import DiskRoute, Crossing

out=Path(__file__).resolve().parent/'output'
for g in (1,2,3,5):
    save_svg(chain_system(g).diagram(), out/f'cut-disks-genus-{g}.svg', title=f'Genus {g}: numbered cut disks')
system=chain_system(1)
route=DiskRoute((Crossing('c2.e1+', .4),), id='one-crossing')
save_svg(system.diagram(route), out/'cut-disks-torus-route.svg', title='A torus curve in its cut disk')
save_svg(chain_system(2,boundaries=('B1','B2'),marks=('M',)).diagram(),
         out/'cut-disks-decorated.svg', title='Genus two with two boundaries and one mark')

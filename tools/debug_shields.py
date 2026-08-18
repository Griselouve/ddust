from PIL import Image
import numpy as np
from scipy import ndimage

SRC = r'E:\Deva\projects\suites\ddust\material\divers_materiel\icons\Gemini_Generated_Image_3lbce43lbce43lbc.png'
BG_TOL=25; DILATION=5; MIN_AREA=40000

img = Image.open(SRC).convert('RGBA')
arr = np.array(img, dtype=np.uint8)
h, w = arr.shape[:2]
corners = np.array([arr[0,0,:3],arr[0,w-1,:3],arr[h-1,0,:3],arr[h-1,w-1,:3]],dtype=float)
bg = corners.mean(axis=0)

is_fg = np.any(np.abs(arr[:,:,:3].astype(float)-bg)>=BG_TOL, axis=2)
is_fgd = ndimage.binary_dilation(is_fg, iterations=DILATION)
labeled,_ = ndimage.label(is_fgd)
slices = ndimage.find_objects(labeled)

shields=[]
for i,slc in enumerate(slices):
    if not slc: continue
    lbl=i+1; size=(labeled[slc]==lbl).sum()
    if size<MIN_AREA: continue
    rmin,rmax=slc[0].start,slc[0].stop-1
    cmin,cmax=slc[1].start,slc[1].stop-1
    shields.append(dict(cy=(rmin+rmax)/2, cx=(cmin+cmax)/2,
                        rmin=rmin, rmax=rmax, cmin=cmin, cmax=cmax))

shields.sort(key=lambda s: s['cy'])
print(f"Image {w}x{h} — {len(shields)} shields")
print(f"{'#':>2}  {'cy':>6}  {'rmin':>5}  {'rmax':>5}  {'cx':>6}  {'cmin':>5}  {'cmax':>5}")
for i,s in enumerate(shields):
    print(f"{i:2d}  {s['cy']:6.0f}  {s['rmin']:5d}  {s['rmax']:5d}  {s['cx']:6.0f}  {s['cmin']:5d}  {s['cmax']:5d}")

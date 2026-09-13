"""Smooth chain constraints for the checked default-genus mesh."""
from math import floor

from .mesh_atlas import cubic_point, cubic_slice
from .disk_routes import ItineraryError

_K=.5522847498307936


def smooth_chain_constraints(surface,coordinates,triangles,boundary,centers,hr,hh,ring_height):
    spacing=surface.handle_spacing
    rx,hy=surface.width/2,surface.height/2
    vy=1 if surface.view_vertical=='above' else -1
    mirror=vy
    radius=hr+spacing*.035
    ry=min(hy*.34,spacing*.17)
    grid_radius=hr+spacing*.10
    vertices=set(v for t in triangles for v in t)
    edges={tuple(sorted((a,t[(i+1)%3]))) for t in triangles for i,a in enumerate(t)}
    by_point={p:v for v,p in coordinates.items() if v in vertices}
    curves={sheet:{} for sheet in ('front','back')}
    fixed={sheet:{} for sheet in curves}

    def ellipse(center):
        raw=(((-radius,0),(-radius,-_K*ry),(-_K*radius,-ry),(0,-ry)),
             ((0,-ry),(_K*radius,-ry),(radius,-_K*ry),(radius,0)),
             ((radius,0),(radius,_K*ry),(_K*radius,ry),(0,ry)),
             ((0,ry),(-_K*radius,ry),(-radius,_K*ry),(-radius,0)))
        return tuple(tuple((center+x,mirror*y) for x,y in c) for c in raw)
    ellipses=[ellipse(c) for c in centers]
    odd={}
    for i in range(surface.genus+1):
        left=-rx if i==0 else centers[i-1]+hr
        right=rx if i==surface.genus else centers[i]-hr
        a,b=boundary[by_point[left,0.]],boundary[by_point[right,0.]]
        width=b[0]-a[0]
        for sheet,sign in (('front',-vy),('back',vy)):
            lift=sign*min(hy*.24,width*.32)
            odd[i,sheet]=(a,(a[0]+width/3,a[1]+lift),(b[0]-width/3,b[1]+lift),b)

    def inverse_x(cubic,x):
        lo,hi=0.,1.
        increasing=cubic[-1][0]>cubic[0][0]
        for _ in range(48):
            t=(lo+hi)/2
            if (cubic_point(cubic,t)[0]<x)==increasing:
                lo=t
            else:
                hi=t
        return (lo+hi)/2

    crossing_u=[]
    crossing_t={}
    for i,center in enumerate(centers):
        values=[]
        for side,quarter,lo,hi,odd_index in ((0,0,center-radius,center,i),
                                            (1,1,center,center+radius,i+1)):
            e=ellipses[i][quarter]
            o=odd[odd_index,'front']
            lo=max(lo,o[0][0]); hi=min(hi,o[-1][0])
            def difference(x):
                et=inverse_x(e,x)
                ot=(x-o[0][0])/(o[-1][0]-o[0][0])
                return cubic_point(e,et)[1]-cubic_point(o,ot)[1]
            f0,f1=difference(lo),difference(hi)
            if f0*f1>=0:
                raise ItineraryError('smooth chain has no transverse corridor intersection')
            for _ in range(48):
                mid=(lo+hi)/2
                fm=difference(mid)
                if f0*fm>0:
                    lo=mid; f0=fm
                else:
                    hi=mid
            x=(lo+hi)/2
            values.append(quarter+inverse_x(e,x))
            canonical=center-hr-spacing*.10 if side==0 else center+hr+spacing*.10
            crossing_t[odd_index,canonical]=(x-o[0][0])/(o[-1][0]-o[0][0])
        crossing_u.append(tuple(values))

    def store(sheet,a,b,controls):
        curves[sheet][a,b]=controls
        curves[sheet][b,a]=tuple(reversed(controls))
        for v,p in ((a,controls[0]),(b,controls[-1])):
            if v in fixed[sheet] and sum((x-y)**2 for x,y in zip(p,fixed[sheet][v]))>1e-12:
                raise ItineraryError('smooth chain constraints disagree at a genuine intersection')
            fixed[sheet][v]=p

    for i in range(surface.genus+1):
        left=-rx if i==0 else centers[i-1]+hr
        right=rx if i==surface.genus else centers[i]-hr
        for sheet in curves:
            anchors=[(left,0.),(right,1.)]
            if sheet=='front':
                anchors.extend((x,t) for (j,x),t in crossing_t.items() if j==i)
            anchors.sort()
            def parameter(x):
                for (a,ta),(b,tb) in zip(anchors,anchors[1:]):
                    if a-1e-8<=x<=b+1e-8:
                        return ta+(tb-ta)*(x-a)/(b-a)
                raise ItineraryError('corridor node outside its chain chart')
            for a,b in edges:
                x,y=coordinates[a]; u,v=coordinates[b]
                if y==v==0 and left<=x<u<=right:
                    store(sheet,a,b,cubic_slice(odd[i,sheet],parameter(x),parameter(u)))

    for i,center in enumerate(centers):
        left,right=center-hr-spacing*.10,center+hr+spacing*.10
        ul,ur=crossing_u[i]
        def parameter(x,y):
            y*=mirror
            if y<=0:
                if x<=center:
                    d=-y if abs(x-left)<1e-8 else ring_height+x-left
                    return ul+(1-ul)*d/(ring_height+grid_radius)
                d=x-center if abs(y+ring_height)<1e-8 else grid_radius+y+ring_height
                return 1+(ur-1)*d/(ring_height+grid_radius)
            if abs(x-right)<1e-8 and y<=hh:
                return ur+(2-ur)*y/hh
            if x>=center:
                d=y-hh if abs(x-right)<1e-8 else ring_height-hh+right-x
                return 2+d/(ring_height-hh+grid_radius)
            if abs(x-left)<1e-8 and y<=hh:
                return 4+ul*(hh-y)/hh
            d=center-x if abs(y-ring_height)<1e-8 else grid_radius+ring_height-y
            return 3+d/(ring_height-hh+grid_radius)
        for a,b in edges:
            x,y=coordinates[a]; u,v=coordinates[b]
            horizontal=(y==v and abs(y)==ring_height and left<=x<u<=right)
            vertical=(x==u and x in (left,right) and -ring_height<=y<v<=ring_height)
            if not (horizontal or vertical):
                continue
            t0,t1=parameter(x,y),parameter(u,v)
            if abs(t1-t0)>2:
                if t0<t1: t0+=4
                else: t1+=4
            reverse=t0>t1
            lo,hi=sorted((t0,t1))
            quarter=floor(lo+1e-9)
            if hi>quarter+1+1e-8:
                raise ItineraryError('chain edge spans a cubic chart corner; refine the grid')
            controls=cubic_slice(ellipses[i][quarter%4],max(0,lo-quarter),min(1,hi-quarter))
            store('front',a,b,tuple(reversed(controls)) if reverse else controls)
    return fixed,curves

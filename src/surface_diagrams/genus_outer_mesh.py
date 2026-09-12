"""Experimental outer boundary charts for top/bottom exchanged rim pairs.

Each rim half is a genuine, unpaired boundary edge. Other outer edges remain
front/back seams. The topology is supplied by this classification, not inferred
from the rendered stroke intersections. These edge charts alone do not certify
a surface mesh; inward collar cusps need a separate local projection model.
"""
from .mesh_atlas import cubic_point, cubic_slice
from .disk_routes import ItineraryError


def _cubics(commands):
    point=tuple(commands[0][1:])
    result=[]
    for command in commands[1:]:
        if command[0] != 'C':
            raise ItineraryError('outer chart needs explicit cubic contours')
        curve=(point,tuple(command[1:3]),tuple(command[3:5]),tuple(command[5:7]))
        result.append(curve)
        point=curve[-1]
    return result


def _inverse(curve,x):
    if abs(x-curve[0][0])<1e-9:return 0.
    if abs(x-curve[-1][0])<1e-9:return 1.
    lo,hi=0.,1.
    for _ in range(52):
        mid=(lo+hi)/2
        if cubic_point(curve,mid)[0]<x:lo=mid
        else:hi=mid
    return (lo+hi)/2


class PairedOuterChart:
    def __init__(self,surface,drawing):
        if surface.type_i or any(p.side in ('left','right') for p in surface.type_ii):
            raise NotImplementedError('this experimental chart only handles top/bottom pairs')
        self.rx,self.hy=surface.width/2,surface.height/2
        self.inner=(surface.genus-1)*surface.handle_spacing/2
        self.spacing=surface.handle_spacing
        self.curves={}
        for sheet in ('front','back'):
            for sign in (1,-1):
                pieces=[]
                for commands in drawing.contours:
                    for curve in _cubics(commands):
                        if sign*sum(p[1] for p in curve)<=0:continue
                        if curve[0][0]>curve[-1][0]:curve=tuple(reversed(curve))
                        pieces.append((curve,None))
                for rim in drawing.rims:
                    if sign*rim.y<=0:continue
                    half=1 if rim.hidden_inner else -1
                    if sheet=='back':half=-half
                    pieces.extend((curve,rim.id) for curve in _cubics(rim.half(half)))
                pieces.sort(key=lambda item:item[0][0][0])
                for (a,_),(b,_) in zip(pieces,pieces[1:]):
                    if sum((x-y)**2 for x,y in zip(a[-1],b[0]))>1e-12:
                        raise ItineraryError('outer rim chart has a discontinuous join')
                self.curves[sheet,sign]=pieces
        pieces=self.curves['front',1]
        self.left,self.right=pieces[0][0][0][0],pieces[-1][0][-1][0]
        self.low=self.left+surface.handle_spacing*.15
        self.high=self.right-surface.handle_spacing*.15
        if not self.low < -self.inner <= self.inner < self.high:
            raise ItineraryError('outer collars leave no checked handle corridor')

    def _top_x(self,x):
        if x < -self.inner:
            return -self.inner+(x+self.inner)*(-self.low-self.inner)/(self.rx-self.inner)
        if x > self.inner:
            return self.inner+(x-self.inner)*(self.high-self.inner)/(self.rx-self.inner)
        return x

    def refine(self,xs,ys):
        xs,ys=set(xs),set(ys)
        band=max(y for y in ys if y<self.hy)
        for i in range(1,4):
            value=band+(self.hy-band)*i/4
            ys.update((value,-value))
        for pieces in self.curves.values():
            for curve,_ in pieces:
                samples=(0.,.25,.5,.75,1.) if curve[-1][0]-curve[0][0]<self.spacing*.10 else (0.,1.)
                for x,y in (cubic_point(curve,t) for t in samples):
                    if x < self.low:
                        value=self.hy*(x-self.left)/(self.low-self.left)
                        ys.update((value,-value))
                    elif x > self.high:
                        value=self.hy*(self.right-x)/(self.right-self.high)
                        ys.update((value,-value))
                    elif x < -self.inner:
                        xs.add(-self.inner+(x+self.inner)*(self.rx-self.inner)/(-self.low-self.inner))
                    elif x > self.inner:
                        xs.add(self.inner+(x-self.inner)*(self.rx-self.inner)/(self.high-self.inner))
                    else:xs.add(x)
        def distinct(values):
            result=[]
            for value in sorted(values):
                if not result or value-result[-1]>1e-8:result.append(value)
            return result
        return distinct(xs),distinct(ys)

    def edge(self,a,b,sheet):
        x,y=a;u,v=b
        sign=1 if y+v>=0 else -1
        def parameter(x,y):
            if abs(x+self.rx)<1e-8:
                return self.left+abs(y)/self.hy*(self.low-self.left)
            if abs(x-self.rx)<1e-8:
                return self.right-abs(y)/self.hy*(self.right-self.high)
            return self._top_x(x)
        start,end=parameter(x,y),parameter(u,v)
        lo,hi=sorted((start,end))
        pieces=self.curves[sheet,sign]
        matches=[(c,boundary) for c,boundary in pieces if c[0][0]-1e-7<=lo and hi<=c[-1][0]+1e-7]
        if len(matches)!=1:
            raise ItineraryError('outer edge spans a curve join; refine its chart')
        curve,boundary=matches[0]
        controls=cubic_slice(curve,_inverse(curve,lo),_inverse(curve,hi))
        return (controls if start<end else tuple(reversed(controls))),boundary

# Standard chain systems (P4 work in progress)

`standard_cuts.chain_system(g, boundaries=(), marks=())` constructs an explicit
2g+1 chain, split at its 2g genuine intersections. The rotation at each vertex
alternates the two incident parents. Face walks recover two complementary
disks; the existing validator checks genus, all parent walks, and incidence.
Genus one has three chain members, including the distinct parallel end curves.

Each supplied boundary or mark is inserted into a complementary disk with a
numbered spoke. The anchor chain edge is subdivided, preserving its parent
number. A new `Attachment` record distinguishes a spoke ending on a cut from
a transverse intersection. Omitting a boundary spoke leaves an annulus;
omitting a marked-point spoke leaves an interior mark. Both are tested.

This is the topological portion of P4a, not yet a binding to genus drawings.
Default decorations alternate between the two disks. A physical presentation
must use an embedding consistent with those placements or construct an explicit
compatible cellulation. Matching surface counts is not enough.

The standard odd-chain neighborhood convention agrees with the chain relation
in [A Note on the Generating Sets for the Mapping Class Groups](https://dergipark.org.tr/en/download/article-file/1481705).
The implementation checks its own cellulation rather than using that convention
as a substitute for certification.

Verification: six new tests cover genera 1,2,3,5,8, boundary/mark cross-products,
stable numbers, missing spokes and false attachments. Next: disk routing and
numbered diagnostics, followed by checked bindings to the surface presentation.

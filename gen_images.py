import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
from mpl_toolkits.mplot3d import Axes3D
from mpl_toolkits.mplot3d.art3d import Poly3DCollection
import os

OUT = os.path.join(os.path.dirname(__file__), "assets")
os.makedirs(OUT, exist_ok=True)

NAVY = "#1F3864"
BLUE = "#2E75B6"
LIGHT = "#D9E2F3"
ACCENT = "#ED7D31"
GREY = "#595959"
plt.rcParams.update({"font.size": 12, "font.family": "DejaVu Sans",
                     "axes.edgecolor": GREY, "text.color": "#222222",
                     "axes.labelcolor": "#222222", "xtick.color": GREY,
                     "ytick.color": GREY})


def save(fig, name):
    path = os.path.join(OUT, name + ".png")
    fig.savefig(path, dpi=150, bbox_inches="tight", facecolor="white")
    plt.close(fig)
    print("saved", path)


def style(ax):
    ax.set_facecolor("white")
    for s in ("top", "right"):
        ax.spines[s].set_visible(False)


# 01 coordinate systems
def coord_systems():
    fig = plt.figure(figsize=(7, 5))
    ax = fig.add_subplot(111, projection="3d")
    ax.set_box_aspect((1, 1, 1))
    o = np.array([0, 0, 0])
    ax.quiver(0, 0, 0, 3, 0, 0, color=ACCENT, arrow_length_ratio=0.12, linewidth=2)
    ax.quiver(0, 0, 0, 0, 3, 0, color=BLUE, arrow_length_ratio=0.12, linewidth=2)
    ax.quiver(0, 0, 0, 0, 0, 3, color=NAVY, arrow_length_ratio=0.12, linewidth=2)
    ax.text(3.2, 0, 0, "X (right)", color=ACCENT, weight="bold")
    ax.text(0, 3.2, 0, "Y (up)", color=BLUE, weight="bold")
    ax.text(0, 0, 3.2, "Z (depth)", color=NAVY, weight="bold")
    # model -> world -> view -> clip note
    ax.scatter([1], [1], [1], color="black", s=40)
    ax.text(1.1, 1.1, 1.1, "Object", color="black")
    ax.set_xlim(0, 3.5); ax.set_ylim(0, 3.5); ax.set_zlim(0, 3.5)
    ax.set_xlabel("Model/World/View/Clip"); ax.set_ylabel(""); ax.set_zlabel("")
    ax.set_title("Essential Coordinate Systems", weight="bold", color=NAVY)
    ax.grid(True, alpha=0.3)
    save(fig, "coord_systems")


# 02 vertices normals textures
def vnt():
    fig = plt.figure(figsize=(7, 5))
    ax = fig.add_subplot(111, projection="3d")
    verts = np.array([[0, 0, 0], [1, 0, 0], [1, 1, 0], [0, 1, 0],
                      [0, 0, 1], [1, 0, 1], [1, 1, 1], [0, 1, 1]])
    faces = [[0, 1, 2, 3], [4, 5, 6, 7], [0, 1, 5, 4],
             [2, 3, 7, 6], [1, 2, 6, 5], [0, 3, 7, 4]]
    ax.add_collection3d(Poly3DCollection([verts[f] for f in faces],
                         facecolors=LIGHT, edgecolors=NAVY, linewidths=1.5, alpha=0.85))
    ax.scatter(verts[:, 0], verts[:, 1], verts[:, 2], color=ACCENT, s=60, zorder=5)
    ax.quiver(0.5, 0.5, 1, 0, 0, 1.2, color=BLUE, arrow_length_ratio=0.2)
    ax.text(0.55, 0.55, 2.2, "normal", color=BLUE)
    ax.quiver(0.5, 0.5, 0, 1, 0.4, 0, color=GREY, arrow_length_ratio=0.2)
    ax.text(1.6, 0.9, 0, "UV texture", color=GREY)
    ax.set_xlim(-0.2, 2); ax.set_ylim(-0.2, 2); ax.set_zlim(-0.2, 2.5)
    ax.set_title("Vertices + Normals + Textures", weight="bold", color=NAVY)
    ax.set_axis_off()
    save(fig, "vnt")


# 03 rendering projection
def rendering():
    fig = plt.figure(figsize=(7, 5))
    ax = fig.add_subplot(111)
    style(ax)
    # 3D scene
    theta = np.linspace(0, 2 * np.pi, 60)
    ax.plot(1 + 0.8 * np.cos(theta), 0.8 * np.sin(theta), color=NAVY, lw=3, label="3D scene")
    # camera
    ax.plot([3.2, 3.2], [-0.2, 1.8], color=GREY, lw=2)
    ax.scatter([3.2], [0.8], color=ACCENT, s=80)
    ax.text(3.3, 0.8, "camera", color=ACCENT)
    # projection rays
    for a in np.linspace(0, np.pi, 7):
        x, y = 1 + 0.8 * np.cos(a), 0.8 * np.sin(a)
        ax.plot([x, 3.2], [y, 0.8], color=LIGHT, lw=1.5)
    # 2D image plane
    ax.add_patch(plt.Rectangle((4.2, 0.2), 0.05, 1.2, color=BLUE))
    ax.text(4.4, 0.7, "2D image", color=BLUE)
    ax.annotate("", xy=(4.2, 0.8), xytext=(3.25, 0.8),
                arrowprops=dict(arrowstyle="->", color=GREY))
    ax.set_xlim(-0.2, 5); ax.set_ylim(-0.5, 2)
    ax.set_title("Rendering = Project 3D → 2D", weight="bold", color=NAVY)
    ax.set_yticks([]); ax.set_xticks([])
    save(fig, "rendering")


# 04 pipeline
def pipeline():
    fig = plt.figure(figsize=(8, 4.5))
    ax = fig.add_subplot(111); style(ax)
    stages = ["Modeling", "Layout / Scene", "Animation", "Rendering", "Output"]
    colors = [BLUE, NAVY, ACCENT, "#548235", GREY]
    for i, (s, c) in enumerate(zip(stages, colors)):
        ax.add_patch(plt.Rectangle((i * 1.7, 0.4), 1.5, 1.2, color=c, alpha=0.9))
        ax.text(i * 1.7 + 0.75, 1.0, s, color="white", ha="center", va="center", weight="bold")
        if i < len(stages) - 1:
            ax.annotate("", xy=((i + 1) * 1.7, 1.0), xytext=(i * 1.7 + 1.5, 1.0),
                        arrowprops=dict(arrowstyle="->", color=GREY, lw=2))
    ax.set_xlim(-0.2, 8.6); ax.set_ylim(0.2, 1.8)
    ax.set_title("Production Pipeline", weight="bold", color=NAVY)
    ax.set_yticks([]); ax.set_xticks([])
    save(fig, "pipeline")


# 05 math concepts
def math_concepts():
    fig = plt.figure(figsize=(6, 5))
    ax = fig.add_subplot(111); style(ax)
    items = ["Vectors & Points", "Matrices", "Linear Algebra",
             "Trigonometry", "Coordinate Transforms", "Quaternions"]
    x = np.arange(len(items))
    vals = [5, 5, 4, 4, 5, 3]
    bars = ax.barh(x, vals, color=BLUE)
    for b, v in zip(bars, vals):
        ax.text(v + 0.1, b.get_y() + b.get_height() / 2, str(v), va="center", color=NAVY)
    ax.set_yticks(x); ax.set_yticklabels(items)
    ax.invert_yaxis()
    ax.set_xlim(0, 6)
    ax.set_title("Core Math to Master", weight="bold", color=NAVY)
    save(fig, "math_concepts")


# 06 point cloud
def point_cloud():
    fig = plt.figure(figsize=(7, 5))
    ax = fig.add_subplot(111, projection="3d")
    rng = np.random.default_rng(1)
    pts = rng.normal(0, 1, (600, 3))
    ax.scatter(pts[:, 0], pts[:, 1], pts[:, 2], s=6, color=BLUE, alpha=0.6)
    ax.set_title("Point Cloud (scanned data)", weight="bold", color=NAVY)
    ax.set_axis_off()
    save(fig, "point_cloud")


# 07 half edge winged edge
def halfedge():
    fig = plt.figure(figsize=(7, 5))
    ax = fig.add_subplot(111); style(ax)
    nodes = np.array([[0, 2], [2, 2], [2, 0], [0, 0]])
    for i, j in [(0, 1), (1, 2), (2, 3), (3, 0), (0, 2)]:
        ax.plot([nodes[i, 0], nodes[j, 0]], [nodes[i, 1], nodes[j, 1]], color=NAVY, lw=2)
    ax.scatter(nodes[:, 0], nodes[:, 1], color=ACCENT, s=80)
    # half-edge arrows
    for i in range(4):
        j = (i + 1) % 4
        mx, my = (nodes[i] + nodes[j]) / 2
        dx, dy = (nodes[j] - nodes[i]) / 2
        ax.arrow(nodes[i, 0], nodes[i, 1], dx * 0.8, dy * 0.8,
                 head_width=0.12, color=BLUE, length_includes_head=True)
    ax.text(-0.5, 1.5, "Half-edge: each edge\nhas 2 directed halves", color=BLUE)
    ax.text(-0.5, -0.4, "Winged-edge: edge stores\npointer to 2 faces/verts", color=GREY)
    ax.set_xlim(-0.7, 2.6); ax.set_ylim(-0.6, 2.6)
    ax.set_title("Half-edge vs Winged-edge", weight="bold", color=NAVY)
    ax.set_yticks([]); ax.set_xticks([])
    save(fig, "halfedge")


# 08 octree kdtree
def octree():
    fig = plt.figure(figsize=(6.5, 5))
    ax = fig.add_subplot(111); style(ax)
    def draw(x, y, s, depth):
        ax.add_patch(plt.Rectangle((x, y), s, s, fill=False, color=NAVY, lw=1.5))
        if depth == 0:
            return
        ns = s / 2
        for i in range(2):
            for j in range(2):
                draw(x + i * ns, y + j * ns, ns, depth - 1)
    draw(0, 0, 4, 2)
    ax.scatter([1, 3, 2.2, 0.5], [3.5, 1, 2.5, 0.8], color=ACCENT, s=50)
    ax.set_xlim(-0.3, 4.3); ax.set_ylim(-0.3, 4.3)
    ax.set_title("Octree spatial subdivision", weight="bold", color=NAVY)
    ax.set_yticks([]); ax.set_xticks([])
    save(fig, "octree")


# 09 triplane
def triplane():
    fig = plt.figure(figsize=(7, 5))
    ax = fig.add_subplot(111); style(ax)
    for i, (c, t) in enumerate([(NAVY, "XY plane"), (BLUE, "YZ plane"), (ACCENT, "XZ plane")]):
        ax.add_patch(plt.Rectangle((0.5 + i * 2.3, 1.5), 1.8, 1.8, color=c, alpha=0.8))
        ax.text(1.4 + i * 2.3, 2.4, t, color="white", ha="center", weight="bold")
    ax.scatter([3], [1.2], color="black", s=60)
    ax.text(3, 0.8, "query point →\nfeatures from 3 planes", color=GREY, ha="center")
    ax.set_xlim(0, 8.2); ax.set_ylim(0.4, 3.6)
    ax.set_title("Tri-plane Neural Encoding", weight="bold", color=NAVY)
    ax.set_yticks([]); ax.set_xticks([])
    save(fig, "triplane")


# 10 buffers
def buffers():
    fig = plt.figure(figsize=(7, 4.5))
    ax = fig.add_subplot(111); style(ax)
    ax.add_patch(plt.Rectangle((0.3, 2.6), 1.2, 0.8, color=BLUE))
    ax.text(0.9, 3.0, "Vertices", color="white", ha="center", va="center")
    ax.add_patch(plt.Rectangle((0.3, 1.6), 1.2, 0.8, color=NAVY))
    ax.text(0.9, 2.0, "Indices", color="white", ha="center", va="center")
    ax.add_patch(plt.Rectangle((3.0, 2.1), 1.6, 1.3, color=ACCENT, alpha=0.85))
    ax.text(3.8, 2.75, "Half-edge mesh", color="white", ha="center", va="center")
    ax.text(3.8, 2.3, "(rich topology)", color="white", ha="center", fontsize=9)
    ax.annotate("", xy=(2.5, 2.0), xytext=(1.5, 2.7),
                arrowprops=dict(arrowstyle="->", color=GREY))
    ax.set_xlim(-0.2, 5.2); ax.set_ylim(1.2, 3.9)
    ax.set_title("Vertex/Index vs Topology", weight="bold", color=NAVY)
    ax.set_yticks([]); ax.set_xticks([])
    save(fig, "buffers")


# 11 scene graph 3d vs 2d
def scenegraph():
    fig = plt.figure(figsize=(7.5, 5))
    ax = fig.add_subplot(111); style(ax)
    def node(x, y, t, c):
        ax.add_patch(plt.Rectangle((x, y), 1.4, 0.6, color=c, alpha=0.9))
        ax.text(x + 0.7, y + 0.3, t, color="white", ha="center", va="center", fontsize=10)
    node(3.3, 4.2, "World", NAVY)
    for i, t in enumerate(["Room", "Object", "Camera"]):
        node(0.5 + i * 2.6, 3.0, t, BLUE)
        ax.plot([4.0, 1.2 + i * 2.6], [4.2, 3.6], color=GREY, lw=1.5)
    node(0.5, 1.8, "Sub-object", ACCENT)
    node(3.1, 1.8, "View frustum", ACCENT)
    ax.plot([1.2, 1.2], [3.0, 2.4], color=GREY, lw=1.5)
    ax.plot([4.4, 3.8], [3.0, 2.4], color=GREY, lw=1.5)
    ax.set_xlim(-0.2, 7.2); ax.set_ylim(1.4, 5.0)
    ax.set_title("3D Scene Graph Hierarchy", weight="bold", color=NAVY)
    ax.set_yticks([]); ax.set_xticks([])
    save(fig, "scenegraph")


# 12 node attributes
def node_attrs():
    fig = plt.figure(figsize=(6, 5))
    ax = fig.add_subplot(111); style(ax)
    attrs = ["Transform (T,R,S)", "Geometry ref", "Material", "Bounding box",
             "Parent/Child", "Visibility", "Metadata"]
    y = np.arange(len(attrs))
    ax.barh(y, [5] * len(attrs), color=LIGHT, edgecolor=BLUE)
    ax.set_yticks(y); ax.set_yticklabels(attrs)
    ax.invert_yaxis(); ax.set_xlim(0, 5.5)
    ax.set_title("Object Node Attributes", weight="bold", color=NAVY)
    save(fig, "node_attrs")


# 13 multiview
def multiview():
    fig = plt.figure(figsize=(7, 4.5))
    ax = fig.add_subplot(111); style(ax)
    for i, ang in enumerate([0, 120, 240]):
        ax.add_patch(plt.Rectangle((i * 2.4, 1.2), 1.8, 1.8, color=BLUE, alpha=0.8))
        ax.text(i * 2.4 + 0.9, 2.1, f"view {i+1}", color="white", ha="center")
        ax.text(i * 2.4 + 0.9, 1.6, f"{ang}\u00b0", color="white", ha="center", fontsize=9)
    ax.scatter([3.6], [0.6], color=ACCENT, s=60)
    ax.text(3.6, 0.2, "shared 3D model", color=ACCENT, ha="center")
    ax.set_xlim(-0.2, 7.4); ax.set_ylim(0, 3.2)
    ax.set_title("Multi-view Consistency", weight="bold", color=NAVY)
    ax.set_yticks([]); ax.set_xticks([])
    save(fig, "multiview")


# 14 gibson
def gibson():
    fig = plt.figure(figsize=(7, 4.5))
    ax = fig.add_subplot(111); style(ax)
    ax.imshow(np.random.rand(40, 60), cmap="viridis", extent=[0, 6, 0, 4])
    ax.contour(np.random.rand(40, 60), levels=4, colors="white", linewidths=1, extent=[0, 6, 0, 4])
    ax.set_title("Gibson dataset: segmentation", weight="bold", color=NAVY)
    ax.set_yticks([]); ax.set_xticks([])
    save(fig, "gibson")


# 15 rotation matrix
def rot_matrix():
    fig = plt.figure(figsize=(6.5, 5))
    ax = fig.add_subplot(111); style(ax)
    M = (r"$R_z(\theta) = [\cos\theta,-\sin\theta,0; $"
         r"$\sin\theta,\cos\theta,0; 0,0,1]$")
    ax.text(0.5, 3.4, "Arbitrary-axis rotation", weight="bold", color=NAVY, fontsize=13)
    ax.text(0.5, 2.2, M, fontsize=15)
    ax.text(0.5, 0.8, "Rodrigues' formula builds R from\naxis k and angle \u03b8", color=GREY)
    ax.set_xlim(0, 7); ax.set_ylim(0, 4)
    ax.axis("off")
    save(fig, "rot_matrix")


# 16 homo 4x4 vs 3x3
def homo44():
    fig = plt.figure(figsize=(7, 5))
    ax = fig.add_subplot(111); style(ax)
    ax.add_patch(plt.Rectangle((0.3, 2.4), 2.0, 1.6, color=BLUE, alpha=0.85))
    ax.text(1.3, 3.2, "3x3", color="white", ha="center", weight="bold")
    ax.text(1.3, 2.7, "rotation/scale", color="white", ha="center", fontsize=9)
    ax.add_patch(plt.Rectangle((3.6, 2.0), 2.6, 2.4, color=NAVY, alpha=0.9))
    ax.text(4.9, 3.9, "4x4 homogeneous", color="white", ha="center", weight="bold")
    ax.text(4.9, 3.4, "rotation+translation\nin one matrix", color="white", ha="center", fontsize=9)
    ax.annotate("", xy=(3.4, 3.2), xytext=(2.4, 3.2),
                arrowprops=dict(arrowstyle="->", color=ACCENT, lw=2))
    ax.set_xlim(0, 6.6); ax.set_ylim(1.6, 4.6)
    ax.set_title("3x3 vs 4x4 Matrices", weight="bold", color=NAVY)
    ax.set_yticks([]); ax.set_xticks([])
    save(fig, "homo44")


# 17 why homogeneous
def why_homo():
    fig = plt.figure(figsize=(7, 4.5))
    ax = fig.add_subplot(111); style(ax)
    ax.text(0.2, 3.4, "Translation is NOT linear in 3D:", weight="bold", color=NAVY)
    ax.text(0.2, 2.7, r"$p' = p + t$  ... cannot be one matrix", color=GREY, fontsize=12)
    ax.text(0.2, 2.0, "p'_h = [R | t ; 0 | 1] p_h", fontsize=14, color=NAVY)
    ax.text(0.2, 1.0, "Homogeneous coords let us compose\nevery transform as matrix multiplication", color=ACCENT)
    ax.set_xlim(0, 7); ax.set_ylim(0, 4)
    ax.axis("off")
    save(fig, "why_homo")


# 18 shear reflection
def shear_reflect():
    fig = plt.figure(figsize=(7, 4.5))
    ax = fig.add_subplot(111, projection="3d")
    # original cube
    z = np.array([[0,0,0],[1,0,0],[1,1,0],[0,1,0],[0,0,1],[1,0,1],[1,1,1],[0,1,1]], dtype=float)
    f = [[0,1,2,3],[4,5,6,7],[0,1,5,4],[2,3,7,6],[1,2,6,5],[0,3,7,4]]
    ax.add_collection3d(Poly3DCollection([z[i] for i in f], facecolors=LIGHT, edgecolors=NAVY, alpha=0.6))
    # sheared
    z2 = z.copy(); z2[:,1] += 0.5*z2[:,0]
    ax.add_collection3d(Poly3DCollection([z2[i] for i in f], facecolors=ACCENT, edgecolors=GREY, alpha=0.4))
    ax.set_title("Shear & Reflection in 3D", weight="bold", color=NAVY)
    ax.set_axis_off()
    save(fig, "shear_reflect")


# 19 transform order
def transform_order():
    fig = plt.figure(figsize=(7.5, 4.5))
    ax = fig.add_subplot(111); style(ax)
    ax.text(0.2, 3.6, "Local \u2192 Parent \u2192 World", weight="bold", color=NAVY, fontsize=13)
    chain = ["Child", "Parent", "Grandparent", "World"]
    x = 0.3
    for i, c in enumerate(chain):
        ax.add_patch(plt.Rectangle((x, 2.2), 1.4, 0.8, color=[ACCENT, BLUE, NAVY, GREY][i], alpha=0.9))
        ax.text(x + 0.7, 2.6, c, color="white", ha="center", va="center", fontsize=9)
        if i < 3:
            ax.annotate("", xy=(x + 1.6, 2.6), xytext=(x + 1.4, 2.6),
                        arrowprops=dict(arrowstyle="->", color=GREY, lw=2))
        x += 1.6
    ax.text(0.2, 1.2, "M_world = M_grand \u00b7 M_parent \u00b7 M_child\n(order matters!)", fontsize=12, color=ACCENT)
    ax.set_xlim(0, 6.6); ax.set_ylim(0.8, 3.9)
    ax.set_yticks([]); ax.set_xticks([])
    save(fig, "transform_order")


if __name__ == "__main__":
    coord_systems(); vnt(); rendering(); pipeline(); math_concepts()
    point_cloud(); halfedge(); octree(); triplane(); buffers()
    scenegraph(); node_attrs(); multiview(); gibson()
    rot_matrix(); homo44(); why_homo(); shear_reflect(); transform_order()
    print("ALL DONE")

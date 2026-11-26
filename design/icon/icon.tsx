// Green Window app icon and favicon, rendered with raea:
//   raea render design/icon/icon.tsx --composition icon|maskable|favicon --alpha -o OUT.png
// Palette: Sanzo Wada no. 271. The mark is the page's own signature: the intensity
// line with the recommended window as its one notch, filled like a pane of glass.
import { AbsoluteFill, Composition, registerRoot } from "raea";

const GROUND = "#94ff94"; // Cobalt Green
const INK = "#0f261f"; // Deep Slate Green
const PANE = "#2dbc94"; // Green Blue

const LINE = "M14 40 L36 40 L36 64 L64 64 L64 40 L86 40";
const NOTCH = "M36 40 L64 40 L64 64 L36 64 Z";

// viewBox 0 0 100 100. `full` = square bleed for maskable icons; otherwise a rounded tile.
// `stroke` thickens for the favicon so the line survives at 16 px.
function Mark({ full, scale = 1, stroke = 8 }: { full?: boolean; scale?: number; stroke?: number }) {
  return (
    <AbsoluteFill style={{ background: "transparent" }}>
      <svg viewBox="0 0 100 100" width="100%" height="100%">
        <rect x="0" y="0" width="100" height="100" rx={full ? 0 : 22} fill={GROUND} />
        <g transform={`translate(${50 - 50 * scale} ${52 - 52 * scale}) scale(${scale})`}>
          <path d={NOTCH} fill={PANE} />
          <path d={LINE} fill="none" stroke={INK} strokeWidth={stroke} strokeLinecap="round" strokeLinejoin="round" />
        </g>
      </svg>
    </AbsoluteFill>
  );
}

registerRoot(() => (
  <>
    <Composition id="icon" width={1024} height={1024} fps={30} durationInFrames={1} component={() => <Mark />} />
    {/* Maskable: mark kept inside the 80% safe circle. */}
    <Composition id="maskable" width={1024} height={1024} fps={30} durationInFrames={1} component={() => <Mark full scale={0.78} />} />
    <Composition id="favicon" width={256} height={256} fps={30} durationInFrames={1} component={() => <Mark stroke={10} />} />
  </>
));

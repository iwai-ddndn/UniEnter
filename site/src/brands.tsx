import {
  siClaude,
  siDiscord,
  siGooglegemini,
  siInstagram,
  siLine,
  siMessenger,
  siX,
} from "simple-icons"

export type Brand = { name: string; hex: string; path?: string; initial?: string }

/*
 * simple-icons収録分は公式ロゴ、未収録(Slack/Teams/ChatGPTはブランド側の要請で
 * simple-iconsから削除済み)はブランドカラーの頭文字タイルでフォールバックする。
 */
export const desktopBrands: Brand[] = [
  { name: "Slack", hex: "4A154B", initial: "S" },
  { name: "Microsoft Teams", hex: "6264A7", initial: "T" },
  { name: "Discord", hex: siDiscord.hex, path: siDiscord.path },
  { name: "LINE", hex: siLine.hex, path: siLine.path },
  { name: "ChatGPT", hex: "10A37F", initial: "G" },
  { name: "Claude", hex: siClaude.hex, path: siClaude.path },
  { name: "Messenger", hex: siMessenger.hex, path: siMessenger.path },
]

export const webOnlyBrands: Brand[] = [
  { name: "Gemini", hex: siGooglegemini.hex, path: siGooglegemini.path },
  { name: "X のDM", hex: "000000", path: siX.path },
  { name: "Instagram のDM", hex: siInstagram.hex, path: siInstagram.path },
]

export function BrandChip({ brand }: { brand: Brand }) {
  return (
    <span className="inline-flex items-center gap-2 rounded-lg border bg-background px-3 py-1.5 text-sm">
      <span
        className="flex size-5 shrink-0 items-center justify-center rounded-md"
        style={{ backgroundColor: `#${brand.hex}` }}
      >
        {brand.path ? (
          <svg viewBox="0 0 24 24" className="size-3.5 fill-white">
            <path d={brand.path} />
          </svg>
        ) : (
          <span className="text-[11px] leading-none font-bold text-white">{brand.initial}</span>
        )}
      </span>
      {brand.name}
    </span>
  )
}

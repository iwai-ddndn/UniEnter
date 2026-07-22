import {
  siClaude,
  siDiscord,
  siGooglegemini,
  siInstagram,
  siLine,
  siMessenger,
  siX,
} from "simple-icons"

export type Service = {
  name: string
  hex: string
  path?: string
  initial?: string
  desktop: boolean
  web: boolean
}

/*
 * simple-icons収録分は公式ロゴ、未収録(Slack/Teams/ChatGPTはブランド側の要請で
 * simple-iconsから削除済み)はブランドカラーの頭文字タイルでフォールバックする。
 */
export const services: Service[] = [
  { name: "Slack", hex: "4A154B", initial: "S", desktop: true, web: true },
  { name: "Microsoft Teams", hex: "6264A7", initial: "T", desktop: true, web: true },
  { name: "LINE", hex: siLine.hex, path: siLine.path, desktop: true, web: false },
  { name: "ChatGPT", hex: "10A37F", initial: "G", desktop: true, web: true },
  { name: "Discord", hex: siDiscord.hex, path: siDiscord.path, desktop: true, web: true },
  { name: "Claude", hex: siClaude.hex, path: siClaude.path, desktop: true, web: true },
  { name: "Gemini", hex: siGooglegemini.hex, path: siGooglegemini.path, desktop: false, web: true },
  { name: "Messenger", hex: siMessenger.hex, path: siMessenger.path, desktop: true, web: true },
  { name: "X(DM)", hex: "000000", path: siX.path, desktop: false, web: true },
  { name: "Instagram(DM)", hex: siInstagram.hex, path: siInstagram.path, desktop: false, web: true },
]

/* アイコン前面の大きめタイル + 名前 + アプリ/ブラウザ対応バッジ */
export function ServiceTile({ service }: { service: Service }) {
  return (
    <div className="flex flex-col items-center gap-2 rounded-xl border bg-card p-4 shadow-sm">
      <span
        className="flex size-12 items-center justify-center rounded-xl"
        style={{ backgroundColor: `#${service.hex}` }}
      >
        {service.path ? (
          <svg viewBox="0 0 24 24" className="size-7 fill-white">
            <path d={service.path} />
          </svg>
        ) : (
          <span className="text-xl leading-none font-bold text-white">{service.initial}</span>
        )}
      </span>
      <span className="text-center text-sm font-medium">{service.name}</span>
      <span className="flex gap-1">
        {service.desktop && (
          <span className="rounded-full bg-secondary px-2 py-0.5 text-[10px] text-muted-foreground">
            アプリ
          </span>
        )}
        {service.web && (
          <span className="rounded-full bg-secondary px-2 py-0.5 text-[10px] text-muted-foreground">
            ブラウザ
          </span>
        )}
      </span>
    </div>
  )
}

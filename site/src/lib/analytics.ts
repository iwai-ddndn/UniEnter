/* GA4イベント送信ヘルパー。gtag未ロード(ブロッカー等)でも安全に何もしない */

declare global {
  interface Window {
    gtag?: (...args: unknown[]) => void
  }
}

export function track(event: string, params?: Record<string, string | number>) {
  window.gtag?.("event", event, params)
}

/** data-track-section属性を持つ要素が初めて表示されたとき section_view を1回だけ送る */
export function observeSections(): () => void {
  const seen = new Set<string>()
  const observer = new IntersectionObserver(
    (entries) => {
      for (const entry of entries) {
        const name = (entry.target as HTMLElement).dataset.trackSection
        if (entry.isIntersecting && name && !seen.has(name)) {
          seen.add(name)
          track("section_view", { section_name: name })
        }
      }
    },
    { threshold: 0.2 },
  )
  document
    .querySelectorAll<HTMLElement>("[data-track-section]")
    .forEach((el) => observer.observe(el))
  return () => observer.disconnect()
}

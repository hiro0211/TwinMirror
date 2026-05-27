import Foundation

struct FAQItem: Identifiable, Hashable {
    let id: String
    let question: String
    let answer: String
}

enum FAQContent {
    static let items: [FAQItem] = [
        FAQItem(
            id: "what-is",
            question: "「ツインミラー」はどんなアプリですか？",
            answer: "二人の顔写真から、AI が合成した「未来の子ども」の想像画像を生成するエンタメ向けのアプリです。本物の遺伝予測ではなく、あくまで AI による創作画像としてお楽しみください。"
        ),
        FAQItem(
            id: "accuracy",
            question: "生成された画像は本当の子どもの姿を予測していますか？",
            answer: "いいえ。AI が雰囲気を再現した創作画像であり、実際の子どもの容姿を予測するものではありません。エンタメ・想像目的でご利用ください。"
        ),
        FAQItem(
            id: "photo-storage",
            question: "アップロードした写真はどこに保存されますか？",
            answer: "アップロードされた顔写真は、生成と結果保存のためにのみ使用されます。生成結果は端末に紐づくクラウドストレージに保存され、他のユーザーに共有されることはありません。詳細は「プライバシーポリシー」をご確認ください。"
        ),
        FAQItem(
            id: "free-vs-premium",
            question: "無料プランと Premium の違いは？",
            answer: "無料プランでは履歴保存数と生成回数に制限があり、結果には透かしが入ります。Premium にご加入いただくと、履歴無制限・透かしなし・優先生成が利用できるようになります。"
        ),
        FAQItem(
            id: "manage-subscription",
            question: "サブスクリプションを解約したい",
            answer: "設定タブの「サブスクリプションを管理」から App Store のサブスクリプション管理画面に移動して解約できます。期間終了の 24 時間前までに解約した場合、次回更新されません。"
        ),
        FAQItem(
            id: "restore-purchase",
            question: "機種変更後に Premium が引き継がれません",
            answer: "設定タブの「購入を復元」をタップしてください。元の購入時と同じ Apple ID でサインインしていれば、Premium が再有効化されます。"
        ),
        FAQItem(
            id: "delete-history",
            question: "履歴をまとめて削除したい",
            answer: "設定タブの「履歴をすべて削除」から一括削除できます。この操作は取り消せないため、ご注意ください。"
        ),
        FAQItem(
            id: "contact",
            question: "問い合わせ先を教えてください",
            answer: "appsupport0326@gmail.com までご連絡ください。設定タブの「お問い合わせ」からメールアプリを起動できます。"
        ),
    ]
}

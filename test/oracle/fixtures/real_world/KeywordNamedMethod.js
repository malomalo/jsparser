export default class Admin extends User {

    static aroundActions = ['requireAdmin']

    async imports () {
        this.display(imports, {
            user: this.application.session.user
        }, { layout })
    }
}

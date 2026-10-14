class ScrollDirective {
    constructor (scrollElement, ...args) {
        this._promise = new Promise((resolve, reject) => {
            function step (now) {

                const elapsed = now - this.start
                // Behavior is (EaseOutCubic)[https://gizma.com/easing/#easeOutCubic]
                // TODO add easing options
                const percent = Math.min(1 - Math.pow(1 - elapsed / this.duration, 3), 1.0)
                scrollElement.scrollTo(this.deltaX * percent + this.startX, this.deltaY * percent + this.startY)
              
                id = window.requestAnimationFrame(step.bind(this))
            }

        })
    }

    setDirective (targetX, targetY, options={}) {
        // support (targetX, options)
        if (typeof targetY == "object") {
            options = targetY
            targetY = undefined
        }
        // support (options)
        if (typeof targetX == "object") {
            options = targetX
            targetX = undefined
        }
        if (!options.duration) {
            this.duration = Math.max(Math.abs(this.deltaY) / this.speed, Math.abs(this.deltaX) / this.speed)
            if (options.minDuration) {
                this.duration = Math.max(this.duration, options.minDuration)
            }
        }
        return this
    }

}

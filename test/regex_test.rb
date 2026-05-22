require 'test_helper'

class JSAnalyzer::RegexTest < Minitest::Test
  
  # test 'regex chars that dont need escaping' do
  #   assert_parse('this._agsAdmin=/(https?:\/\/[^/]+\/[^/]+)\/admin\/?(\/.*)?$/i', <<~JS)
  #       this._agsAdmin = /(https?:\\/\\/[^/]+\\/[^/]+)\\/admin\\/?(\\/.*)?$/i;
  #   JS
  
  #   assert_parse('function T(e){return e.replaceAll(/[|\\{}()[\]^$+*?.]/g,"\\$&")}', <<~JS)
  #       function T(e) {
  #           return e.replaceAll(/[|\\{}()[\\]^$+*?.]/g, "\\$&");
  #       };
  #   JS

  #   assert_parse('f=/(?:LENGTH)?UNIT\[([^\]]+)]]$/i', <<~JS)
  #       f = /(?:LENGTH)?UNIT\\[([^\\]]+)]]$/i;
  #   JS

  #   assert_parse('function o(t,e){return t.replaceAll(/([.$?*|{}()[\]\\\\/+\-^])/g,(t=>e?.includes(t)?t:`\\${t}`))}', <<~JS)
  #       function o(t, e) {
  #           return t.replaceAll(/([.$?*|{}()[\\]\\\\/+\\-^])/g, (t) => e?.includes(t) ? t : `\\${t}`);
  #       };
  #   JS
  # end
  
  test 'a regex after a function call or for loop' do
    
    assert_parse('for(const s in r)/^(request|service)$/i.test(s)&&delete r[s];', <<~JS)
        for(const s in r)/^(request|service)$/i.test(s)&&delete r[s];
    JS

    
    # file 'b.js', <<~JS
    #   e=>Math.round(1e4*e)/1e4;
    # JS

    # asset = assert_file 'b.js', 'application/javascript'
    # file 'c.js', <<~JS
    #   {const e=this._timings.entries,t=e.length;let s=0;for(const r of e)s+=r;r=s/t}
    # JS

    # asset = assert_file 'c.js', 'application/javascript'
  end
  
    # test 'file with a single line comment in a argument list before a regex' do
    #   file 'name.js', <<~JS
    #     function javascript(hljs) {
  
    #       regex.either(
    #         // Float32Array, OutT
    #         /\b[A-Z][a-z]+([A-Z][a-z]*|\d)*/,
    #         // CSSFactory, CSSFactoryT
    #       )
  
    #       const USE_STRICT = {
    #         label: "use_strict",
    #         className: 'meta',
    #         relevance: 10,
    #         begin: /^\s*['"]use (strict|asm)['"]/
    #       };
  
    #     }
  
    #     module.exports = javascript;
    #   JS
  
    #   asset = assert_file 'name.js', 'application/javascript'
      
      
    #   file 'name.js', <<~JS
    #     class ScrollDirective {
    #         constructor (scrollElement, ...args) {
    #             this._promise = new Promise((resolve, reject) => {
    #                 function step (now) {
  
    #                     const elapsed = now - this.start
    #                     // Behavior is (EaseOutCubic)[https://gizma.com/easing/#easeOutCubic]
    #                     // TODO add easing options
    #                     const percent = Math.min(1 - Math.pow(1 - elapsed / this.duration, 3), 1.0)
    #                     scrollElement.scrollTo(this.deltaX * percent + this.startX, this.deltaY * percent + this.startY)
                      
    #                     id = window.requestAnimationFrame(step.bind(this))
    #                 }
  
    #             })
    #         }
      
    #         setDirective (targetX, targetY, options={}) {
    #             // support (targetX, options)
    #             if (typeof targetY == "object") {
    #                 options = targetY
    #                 targetY = undefined
    #             }
    #             // support (options)
    #             if (typeof targetX == "object") {
    #                 options = targetX
    #                 targetX = undefined
    #             }
    #             if (!options.duration) {
    #                 this.duration = Math.max(Math.abs(this.deltaY) / this.speed, Math.abs(this.deltaX) / this.speed)
    #                 if (options.minDuration) {
    #                     this.duration = Math.max(this.duration, options.minDuration)
    #                 }
    #             }
    #             return this
    #         }
  
    #     }
    #   JS
  
    #   asset = assert_file 'name.js', 'application/javascript'
    # end
end
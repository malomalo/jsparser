require 'test_helper'

class JSParser::ClassTest < Minitest::Test

  test 'class definintions' do
    input = <<~JS
        // Declaration
        class Rectangle {
            constructor(height, width) {
                this.height = height;
                this.width = width;
            }
        }
        
        // Expression; the class is anonymous but assigned to a variable
        const Rectangle = class {
            constructor(height, width) {
                this.height = height;
                this.width = width;
            }
        };
        
        // Expression; the class has its own name
        const Rectangle = class Rectangle2 {
            constructor(height, width) {
                this.height = height;
                this.width = width;
            }
        };
        
        
        class Polygon extends Object {
            constructor(height, width) {
                this.area = height * width;
            }
            bar() {
                return "Hello World!";
            }
        };
    JS
    
    assert_parse(input, <<~JS)
        // Declaration
        class Rectangle {
            constructor(height, width) {
                this.height = height;
                this.width = width;
            };
        };
        // Expression; the class is anonymous but assigned to a variable
        const Rectangle = class {
            constructor(height, width) {
                this.height = height;
                this.width = width;
            };
        };
        // Expression; the class has its own name
        const Rectangle = class Rectangle2 {
            constructor(height, width) {
                this.height = height;
                this.width = width;
            };
        };
        class Polygon extends Object {
            constructor(height, width) {
                this.area = height * width;
            };
            bar() {
                return "Hello World!";
            };
        };
    JS
  end
  
  test 'class extends' do
    input = <<~JS
        const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        
        class DateFormatter extends Date {
            getFormattedDate() {
                return `${this.getDate()}-${months[this.getMonth()]}-${this.getFullYear()}`;
            }
        }
    JS
    
    assert_parse(input, <<~JS)
        const months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
        class DateFormatter extends Date {
            getFormattedDate() {
                return `${this.getDate()}-${months[this.getMonth()]}-${this.getFullYear()}`;
            };
        };
    JS
  end
  
  test "class with fields" do
    input = <<~JS
        const PREFIX = "prefix";

        class ClassWithField {
            instanceField;
            instanceFieldWithInitializer = "instance field";
            [`${PREFIX}Field`] = "prefixed field";
            static staticField;
            static staticFieldWithInitializer = "static field";
            static [`${PREFIX}Field`] = "static prefixed field";
        }

        const instance = new ClassWithField();
        console.log(Object.hasOwn(instance, "field")); // true
        console.log(instance.field); // undefined
        console.log(instance.fieldWithInitializer); // "instance field"
        console.log(instance.prefixField); // "prefixed field"
    JS

    assert_parse(input, <<~JS)
        const PREFIX = "prefix";
        class ClassWithField {
            instanceField;
            instanceFieldWithInitializer = "instance field";
            [`${PREFIX}Field`] = "prefixed field";
            static staticField;
            static staticFieldWithInitializer = "static field";
            static [`${PREFIX}Field`] = "static prefixed field";
        };
        const instance = new ClassWithField();
        console.log(Object.hasOwn(instance, "field")); // true
        console.log(instance.field); // undefined
        console.log(instance.fieldWithInitializer); // "instance field"
        console.log(instance.prefixField); // "prefixed field"
    JS
  end
  
  test "class with constructor" do
    input = <<~JS
        class Rectangle {
            constructor(height, width) {
                this.height = height;
                this.width = width;
            }
        }
    JS
    
    assert_parse(input, <<~JS)
        class Rectangle {
            constructor(height, width) {
                this.height = height;
                this.width = width;
            };
        };
    JS
  end
  
  
  test "class with getters" do
    input = <<~JS
        // Declaration
        class Rectangle {
            // Getter
            get area() {
                return this.calcArea();
            }

            // Getter
            static get area() {
                return 42;
            }
        }
    JS
    
    assert_parse(input, <<~JS)
        // Declaration
        class Rectangle {
            // Getter
            get area() {
                return this.calcArea();
            };
            // Getter
            static get area() {
                return 42;
            };
        };
    JS
  end
  
  test "class with setters" do
    input = <<~JS
        /* Declaration */
        class Rectangle {
            /* Setter */
            set area(length) {
                this.area = v**2;
            }
            
            /* Setter */
            static set area(length) {
                this.area = v**2;
            }
        }
    JS
    
    assert_parse(input, <<~JS)
        /* Declaration */
        class Rectangle {
            /* Setter */
            set area(length) {
                this.area = v ** 2;
            };
            /* Setter */
            static set area(length) {
                this.area = v ** 2;
            };
        };
    JS
  end

  test "class with methods" do
    input = <<~JS
        const name = 'fnName';
        // Declaration
        class Rectangle {
            calcArea() {
                return this.height * this.width;
            }
            [name]() {
                return 'name';
            }
            *getSides() {
                yield this.height;
                yield this.width;
            }
            *[name]() {
                yield 'name';
            }
            async calcArea() {
                return this.height * this.width;
            }
            async [name]() {
                return 'name';
            }
            async *getSides() {
                yield this.height;
                yield this.width;
            }
            async *[name]() {
                yield 'name';
            }
            static calcArea() {
                return this.height * this.width;
            }
            static [name]() {
                return 'name';
            }
            static *getSides() {
                yield this.height;
                yield this.width;
            }
            static *[name]() {
                yield 'name';
            }
            static async calcArea() {
                return this.height * this.width;
            }
            static async [name]() {
                return 'name';
            }
            static async *getSides() {
                yield this.height;
                yield this.width;
            }
            static async *[name]() {
                yield 'name';
            }
        }
    JS
    
    assert_parse(input, <<~JS)
        const name = 'fnName';
        // Declaration
        class Rectangle {
            calcArea() {
                return this.height * this.width;
            };
            [name]() {
                return 'name';
            };
            *getSides() {
                yield this.height;
                yield this.width;
            };
            *[name]() {
                yield 'name';
            };
            async calcArea() {
                return this.height * this.width;
            };
            async [name]() {
                return 'name';
            };
            async *getSides() {
                yield this.height;
                yield this.width;
            };
            async *[name]() {
                yield 'name';
            };
            static calcArea() {
                return this.height * this.width;
            };
            static [name]() {
                return 'name';
            };
            static *getSides() {
                yield this.height;
                yield this.width;
            };
            static *[name]() {
                yield 'name';
            };
            static async calcArea() {
                return this.height * this.width;
            };
            static async [name]() {
                return 'name';
            };
            static async *getSides() {
                yield this.height;
                yield this.width;
            };
            static async *[name]() {
                yield 'name';
            };
        };
    JS
  end
  
  test "class with static initializion block" do
    input = <<~JS
        class ClassWithStaticInitializationBlock {
            static staticProperty1 = "Property 1";
            static staticProperty2;
            static {
                this.staticProperty2 = "Property 2";
            }
        }
    JS
    
     assert_parse(input, <<~JS)
        class ClassWithStaticInitializationBlock {
            static staticProperty1 = "Property 1";
            static staticProperty2;
            static {
                this.staticProperty2 = "Property 2";
            };
        };
     JS
  end

  test 'class with private fields' do
    input = <<~JS
        class ClassWithPrivate {
            #privateField;
            #privateFieldWithInitializer = 42;
            
            #privateMethod() {
                // …
            }
            
            static #privateStaticField;
            static #privateStaticFieldWithInitializer = 42;
            
            static #privateStaticMethod() {
                // …
            }
        }
    JS
    
    assert_parse(input, <<~JS)
        class ClassWithPrivate {
            #privateField;
            #privateFieldWithInitializer = 42;
            #privateMethod() {
                // …
            };
            static #privateStaticField;
            static #privateStaticFieldWithInitializer = 42;
            static #privateStaticMethod() {
                // …
            };
        };
    JS
  end

  test 'class extends any member, call or new expression' do
    assert_parse('class A extends B.C {}', "class A extends B.C {\n};")
    assert_parse('class A extends mixin(B, C) {}', "class A extends mixin(B, C) {\n};")
    assert_parse('x = class extends (y ? B : C) {}', "x = class extends (y ? B : C) {\n};")
    assert_parse('class A extends B {}', "class A extends B {\n};")
  end

  test 'quoted member names stay quoted' do
    assert_parse('class A { "x-y"() {} "f" = 1; static "s"; get "g"() {} [key]() {} }', <<~JS)
        class A {
            "x-y"() { };
            "f" = 1;
            static "s";
            get "g"() { };
            [key]() { };
        };
    JS
  end

  test 'members on one line need a semicolon between them' do
    ['class A { a b }', 'class A { accessor x = 1 }', 'class A { x = 1 y = 2 }'].each do |source|
      assert_raises(JSParser::SyntaxError, source) { JSParser.parse(source) }
    end
    assert_parse("class A { x = 1\n y = 2; m() {} n() {} }", "class A {\n    x = 1;\n    y = 2;\n    m() { };\n    n() { };\n};")
  end

  test 'only async is a member name before a line break' do
    assert_parse("class A { static\n x = 1 }", "class A {\n    static x = 1;\n};")
    assert_parse("class A { get\n x() {} }", "class A {\n    get x() { };\n};")
    assert_parse("class A { async\n x() {} }", "class A {\n    async;\n    x() { };\n};")
  end

end

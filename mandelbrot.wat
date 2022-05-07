(module
  (import "env" "memory" (memory 1))
  (global $max_iteration (import "env" "maxIteration") i32)
  (global $width (import "env" "width") i32)
  (global $height (import "env" "height") i32)

  (func $complex_mul_real
    (param $real0 f64)
    (param $imaginary0 f64)
    (param $real1 f64)
    (param $imaginary1 f64)
    (result f64)

    (f64.sub ;; $real0 * $real1 - $imaginary0 * $imaginary1
      (f64.mul (local.get $real0) (local.get $real1))
      (f64.mul (local.get $imaginary0) (local.get $imaginary1))
    )
  )

  (func $complex_mul_imaginary
    (param $real0 f64)
    (param $imaginary0 f64)
    (param $real1 f64)
    (param $imaginary1 f64)
    (result f64)

    (f64.add ;; $real0 * $imaginary1 + $real1 * $imaginary0
      (f64.mul (local.get $real0) (local.get $imaginary1))
      (f64.mul (local.get $real1) (local.get $imaginary0))
    )
  )

  (func $complex_square_real
    (param $real f64)
    (param $imaginary f64)
    (result f64)

    (call $complex_mul_real
      (local.get $real) (local.get $imaginary) (local.get $real) (local.get $imaginary))
  )

  (func $complex_square_imaginary
    (param $real f64)
    (param $imaginary f64)
    (result f64)

    (call $complex_mul_imaginary
      (local.get $real) (local.get $imaginary) (local.get $real) (local.get $imaginary))
  )

  (func $is_divergence
    (param $real f64)
    (param $imaginary f64)
    (result i32)

    (f64.gt ;; ($real * $real + $imaginary * $imaginary) > 4
      (f64.add
        (f64.mul (local.get $real) (local.get $real))
        (f64.mul (local.get $imaginary) (local.get $imaginary))
      )
      (f64.const 4)
    )
  )

  (func $step_mandelbrot_real
    (param $current_real f64)
    (param $current_imaginary f64)
    (param $constant_real f64)
    (result f64)

    (f64.add
      (call $complex_square_real (local.get $current_real) (local.get $current_imaginary))
      (local.get $constant_real)
    )
  )

  (func $step_mandelbrot_imaginary
    (param $current_real f64)
    (param $current_imaginary f64)
    (param $constant_imaginary f64)
    (result f64)

    (f64.add
      (call $complex_square_imaginary (local.get $current_real) (local.get $current_imaginary))
      (local.get $constant_imaginary)
    )
  )

  (func $calculate_divergence_step
    (param $constant_real f64)
    (param $constant_imaginary f64)
    (result i32)

    (local $n i32)
    (local $current_real f64)
    (local $current_imaginary f64)
    (local $next_real f64)
    (local $next_imaginary f64)

    (local.set $current_real (local.get $constant_real)) ;; $current_real = $constant_real
    (local.set $current_imaginary (local.get $constant_imaginary)) ;; $current_imaginary = $constant_imaginary
    (local.set $n (i32.const 0)) ;; $n = 0

    (loop $continue (block $break
      (if
        (call $is_divergence (local.get $current_real) (local.get $current_imaginary))
        (then
          local.get $n
          return
        )
      )

      (br_if $break ;; break if: $n == $max_iteration - 2
        (i32.eq (local.get $n) (i32.sub (global.get $max_iteration) (i32.const 2)))
      )

      (local.set $next_real
        (call $step_mandelbrot_real
          (local.get $current_real) (local.get $current_imaginary) (local.get $constant_real))
      )
      (local.set $next_imaginary
        (call $step_mandelbrot_imaginary
          (local.get $current_real) (local.get $current_imaginary) (local.get $constant_imaginary))
      )

      (local.set $current_real (local.get $next_real))
      (local.set $current_imaginary (local.get $next_imaginary))

      (local.set $n (i32.add (local.get $n) (i32.const 1))) ;; $n += 1
      br $continue
    ))
    (i32.sub (global.get $max_iteration) (i32.const 1)) ;; $max_iteration - 1
  )

  (func $convert_divergence_step_to_color
    (param $divergence_step i32)
    (result i32)

    (i32.trunc_f64_u ;; ($divergence_step / ($max_iteration - 1)) * 255
      (f64.mul
        (f64.div
          (f64.convert_i32_u (local.get $divergence_step))
          (f64.convert_i32_u
            (i32.sub (global.get $max_iteration) (i32.const 1))
          )
        )
        (f64.const 255)
      )
    )
  )

  (func $draw_pixel
    (param $x i32)
    (param $y i32)
    (param $value i32)

    (local $index i32)

    (local.set $index ;; $index = ($x + $y * $width) * 4
      (i32.mul
        (i32.add
          (local.get $x)
          (i32.mul (local.get $y) (global.get $width)
          )
        )
        (i32.const 4)
      )
    )

    (i32.store8 ;; Red: memory[$index] = $value
      (local.get $index)
      (local.get $value)
    )
    (i32.store8 ;; Blue: memory[$index + 1] = $value
      (i32.add (local.get $index) (i32.const 1))
      (local.get $value)
    )
    (i32.store8 ;; Green: memory[$index + 2] = $value
      (i32.add (local.get $index) (i32.const 2))
      (local.get $value)
    )
    (i32.store8 ;; Alpha: memory[$index + 3] = 255
      (i32.add (local.get $index) (i32.const 3))
      (i32.const 255)
    )
  )

  (func (export "update")
    (param $min_x f64)
    (param $min_y f64)
    (param $step_x f64)
    (param $step_y f64)

    (local $x i32)
    (local $y i32)
    (local $constant_real f64)
    (local $constant_imaginary f64)

    (local.set $y (i32.const 0)) ;; $y = 0
    (loop $continue_y
      (local.set $constant_imaginary ;; $constant_imaginary = $min_y + $y * $step_y
        (f64.add
          (local.get $min_y)
          (f64.mul (f64.convert_i32_u (local.get $y)) (local.get $step_y))
        )
      )
      (local.set $x (i32.const 0)) ;; $x = 0
      (loop $continue_x
        (local.set $constant_real ;; $constant_real = $min_x + $x * $step_x
          (f64.add
            (local.get $min_x)
            (f64.mul (f64.convert_i32_u (local.get $x)) (local.get $step_x))
          )
        )

        (call $draw_pixel
          (local.get $x)
          (local.get $y)
          (call $convert_divergence_step_to_color
            (call $calculate_divergence_step (local.get $constant_real) (local.get $constant_imaginary))
          )
        )

        (local.set $x (i32.add (local.get $x) (i32.const 1))) ;; $x += 1
        (br_if $continue_x (i32.lt_u (local.get $x) (global.get $width))) ;; continue if: $x < $width
      )

      (local.set $y (i32.add (local.get $y) (i32.const 1))) ;; $y += 1
      (br_if $continue_y (i32.lt_u (local.get $y) (global.get $height))) ;; continue if: $y < $height
    )
  )
)
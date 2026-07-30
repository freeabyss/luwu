# 前端单元测试示例

## 概述

前端单元测试主要覆盖：
- 组件渲染测试
- 交互行为测试
- 工具函数测试
- Hook 逻辑测试

推荐技术栈：
- **测试框架**：Vitest
- **测试库**：React Testing Library
- **浏览器模拟**：jsdom

---

## 基础配置

### vitest.config.ts

```typescript
import { defineConfig } from 'vitest/config'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  test: {
    environment: 'jsdom',
    globals: true,
    setupFiles: ['./src/test/setup.ts'],
    coverage: {
      provider: 'v8',
      reporter: ['text', 'json', 'html'],
      include: ['src/**/*.{ts,tsx}'],
      exclude: ['src/**/*.d.ts', 'src/**/*.stories.*'],
    },
  },
})
```

### setup.ts

```typescript
import '@testing-library/jest-dom'
import { cleanup } from '@testing-library/react'
import { afterEach } from 'vitest'

afterEach(() => {
  cleanup()
})
```

---

## 示例一：Button 组件测试

### 组件代码

```tsx
// src/components/Button/Button.tsx
import React from 'react'
import './Button.css'

export interface ButtonProps {
  /** 按钮内容 */
  children: React.ReactNode
  /** 点击事件 */
  onClick?: () => void
  /** 是否禁用 */
  disabled?: boolean
  /** 按钮类型 */
  variant?: 'primary' | 'secondary' | 'danger'
  /** 按钮大小 */
  size?: 'small' | 'medium' | 'large'
  /** 加载状态 */
  loading?: boolean
  /** 自定义类名 */
  className?: string
}

export const Button: React.FC<ButtonProps> = ({
  children,
  onClick,
  disabled = false,
  variant = 'primary',
  size = 'medium',
  loading = false,
  className = '',
}) => {
  const handleClick = () => {
    if (!disabled && !loading && onClick) {
      onClick()
    }
  }

  const buttonClass = [
    'btn',
    `btn-${variant}`,
    `btn-${size}`,
    loading ? 'btn-loading' : '',
    disabled ? 'btn-disabled' : '',
    className,
  ]
    .filter(Boolean)
    .join(' ')

  return (
    <button
      className={buttonClass}
      disabled={disabled || loading}
      onClick={handleClick}
      aria-busy={loading}
    >
      {loading && <span className="btn-spinner" aria-hidden="true" />}
      <span className="btn-content">{children}</span>
    </button>
  )
}
```

### 测试代码

```tsx
// src/components/Button/Button.test.tsx
import React from 'react'
import { render, screen, fireEvent } from '@testing-library/react'
import { describe, it, expect, vi } from 'vitest'
import { Button } from './Button'

describe('Button 组件', () => {
  describe('渲染测试', () => {
    it('正确渲染子元素', () => {
      render(<Button>点击我</Button>)
      expect(screen.getByText('点击我')).toBeInTheDocument()
    })

    it('默认使用 primary variant', () => {
      render(<Button>测试</Button>)
      expect(screen.getByRole('button')).toHaveClass('btn-primary')
    })

    it.each([
      ['primary', 'btn-primary'],
      ['secondary', 'btn-secondary'],
      ['danger', 'btn-danger'],
    ])('variant=%s 应用正确的类名', (variant, expectedClass) => {
      render(<Button variant={variant as any}>测试</Button>)
      expect(screen.getByRole('button')).toHaveClass(expectedClass)
    })

    it.each([
      ['small', 'btn-small'],
      ['medium', 'btn-medium'],
      ['large', 'btn-large'],
    ])('size=%s 应用正确的类名', (size, expectedClass) => {
      render(<Button size={size as any}>测试</Button>)
      expect(screen.getByRole('button')).toHaveClass(expectedClass)
    })

    it('禁用状态正确设置 disabled 属性', () => {
      render(<Button disabled>测试</Button>)
      expect(screen.getByRole('button')).toBeDisabled()
      expect(screen.getByRole('button')).toHaveClass('btn-disabled')
    })

    it('加载状态显示 spinner', () => {
      render(<Button loading>提交中</Button>)
      expect(screen.getByRole('button')).toHaveAttribute('aria-busy', 'true')
      expect(document.querySelector('.btn-spinner')).toBeInTheDocument()
    })
  })

  describe('交互测试', () => {
    it('点击时触发 onClick', () => {
      const handleClick = vi.fn()
      render(<Button onClick={handleClick}>点击</Button>)

      fireEvent.click(screen.getByRole('button'))
      expect(handleClick).toHaveBeenCalledTimes(1)
    })

    it('禁用时点击不触发 onClick', () => {
      const handleClick = vi.fn()
      render(<Button onClick={handleClick} disabled>点击</Button>)

      fireEvent.click(screen.getByRole('button'))
      expect(handleClick).not.toHaveBeenCalled()
    })

    it('加载时点击不触发 onClick', () => {
      const handleClick = vi.fn()
      render(<Button onClick={handleClick} loading>提交中</Button>)

      fireEvent.click(screen.getByRole('button'))
      expect(handleClick).not.toHaveBeenCalled()
    })
  })
})
```

---

## 示例二：表单输入组件测试

```tsx
// src/components/Input/Input.test.tsx
import React from 'react'
import { render, screen, fireEvent } from '@testing-library/react'
import { describe, it, expect, vi } from 'vitest'
import { Input } from './Input'

describe('Input 组件', () => {
  it('正确显示占位符', () => {
    render(<Input placeholder="请输入用户名" />)
    expect(screen.getByPlaceholderText('请输入用户名')).toBeInTheDocument()
  })

  it('支持受控模式', () => {
    const handleChange = vi.fn()
    const { rerender } = render(
      <Input value="初始值" onChange={handleChange} />
    )

    expect(screen.getByDisplayValue('初始值')).toBeInTheDocument()

    // 更新值
    rerender(<Input value="更新后的值" onChange={handleChange} />)
    expect(screen.getByDisplayValue('更新后的值')).toBeInTheDocument()
  })

  it('输入时触发 onChange', () => {
    const handleChange = vi.fn()
    render(<Input onChange={handleChange} />)

    const input = screen.getByRole('textbox')
    fireEvent.change(input, { target: { value: '测试输入' } })

    expect(handleChange).toHaveBeenCalledWith('测试输入')
  })

  it('支持清除功能', () => {
    const handleChange = vi.fn()
    render(<Input value="有值" onChange={handleChange} allowClear />)

    // 点击清除按钮
    fireEvent.click(screen.getByRole('button', { name: /clear/i }))
    expect(handleChange).toHaveBeenCalledWith('')
  })

  it('错误状态显示错误样式', () => {
    render(<Input error errorMessage="输入格式错误" />)
    expect(screen.getByRole('textbox')).toHaveClass('input-error')
    expect(screen.getByText('输入格式错误')).toBeInTheDocument()
  })
})
```

---

## 示例三：工具函数测试

```typescript
// src/utils/format.test.ts
import { describe, it, expect } from 'vitest'
import { formatMoney, formatPhone, maskEmail, debounce } from './format'

describe('formatMoney - 金额格式化', () => {
  it('格式化为两位小数', () => {
    expect(formatMoney(99)).toBe('99.00')
    expect(formatMoney(99.9)).toBe('99.90')
    expect(formatMoney(99.999)).toBe('100.00')
  })

  it('处理 null 和 undefined', () => {
    expect(formatMoney(null)).toBe('0.00')
    expect(formatMoney(undefined)).toBe('0.00')
  })

  it('处理负数', () => {
    expect(formatMoney(-99)).toBe('-99.00')
  })
})

describe('formatPhone - 手机号格式化', () => {
  it('格式化为 138-0000-0000', () => {
    expect(formatPhone('13800000000')).toBe('138-0000-0000')
  })

  it('处理带空格的输入', () => {
    expect(formatPhone('138 0000 0000')).toBe('138-0000-0000')
  })

  it('非法输入返回原值', () => {
    expect(formatPhone('123')).toBe('123')
    expect(formatPhone('')).toBe('')
  })
})

describe('maskEmail - 邮箱脱敏', () => {
  it('正常邮箱脱敏', () => {
    expect(maskEmail('zhangsan@example.com')).toBe('zh***@example.com')
  })

  it('短用户名邮箱脱敏', () => {
    expect(maskEmail('a@example.com')).toBe('***@example.com')
  })

  it('非法邮箱返回原值', () => {
    expect(maskEmail('not-email')).toBe('not-email')
  })
})

describe('debounce - 防抖函数', async () => {
  it('延迟执行', async () => {
    const fn = vi.fn()
    const debouncedFn = debounce(fn, 100)

    debouncedFn()
    debouncedFn()
    debouncedFn()

    expect(fn).not.toHaveBeenCalled()

    await new Promise(resolve => setTimeout(resolve, 150))
    expect(fn).toHaveBeenCalledTimes(1)
  })
})
```

---

## 示例四：自定义 Hook 测试

```tsx
// src/hooks/useCounter.test.ts
import { renderHook, act } from '@testing-library/react'
import { describe, it, expect } from 'vitest'
import { useCounter } from './useCounter'

describe('useCounter Hook', () => {
  it('初始值正确', () => {
    const { result } = renderHook(() => useCounter(10))
    expect(result.current.count).toBe(10)
  })

  it('默认初始值为 0', () => {
    const { result } = renderHook(() => useCounter())
    expect(result.current.count).toBe(0)
  })

  it('increment 增加计数', () => {
    const { result } = renderHook(() => useCounter(0))

    act(() => {
      result.current.increment()
    })
    expect(result.current.count).toBe(1)

    act(() => {
      result.current.increment(5)
    })
    expect(result.current.count).toBe(6)
  })

  it('decrement 减少计数', () => {
    const { result } = renderHook(() => useCounter(10))

    act(() => {
      result.current.decrement()
    })
    expect(result.current.count).toBe(9)

    act(() => {
      result.current.decrement(3)
    })
    expect(result.current.count).toBe(6)
  })

  it('reset 重置为初始值', () => {
    const { result } = renderHook(() => useCounter(10))

    act(() => {
      result.current.increment(5)
    })
    expect(result.current.count).toBe(15)

    act(() => {
      result.current.reset()
    })
    expect(result.current.count).toBe(10)
  })

  it('支持最小值限制', () => {
    const { result } = renderHook(() => useCounter(0, { min: -5 }))

    act(() => {
      result.current.decrement(10)
    })
    expect(result.current.count).toBe(-5)
  })

  it('支持最大值限制', () => {
    const { result } = renderHook(() => useCounter(0, { max: 10 }))

    act(() => {
      result.current.increment(15)
    })
    expect(result.current.count).toBe(10)
  })
})
```

---

## 运行测试

```bash
# 运行所有测试
npm run test

# 监听模式
npm run test -- --watch

# 生成覆盖率报告
npm run test -- --coverage

# 运行特定文件
npm run test -- src/components/Button/Button.test.tsx
```

---

## 最佳实践

1. **测试行为而非实现**
   - ✅ 测试用户看到了什么、做了什么
   - ❌ 不要测试内部状态或私有方法

2. **测试命名清晰**
   - `should{期望行为}When{场景条件}`

3. **合理分组**
   - 使用 `describe` 按功能、场景分组测试

4. **使用查询角色**
   - 优先使用 `getByRole`、`getByLabelText`
   - 尽量避免 `getByTestId`

5. **清理副作用**
   - 使用 `afterEach` 清理 mock 和副作用

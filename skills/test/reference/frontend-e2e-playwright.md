# 前端 E2E 功能测试示例（Playwright）

## 概述

> **功能测试（E2E）**：模拟真实用户操作浏览器，验证完整业务流程
>
> - 使用 Playwright 作为测试框架
> - 测试用例与用户操作路径完全一致
> - 覆盖核心业务流程和关键用户场景
> - 支持多浏览器测试（Chrome、Firefox、Safari）

---

## 安装与配置

### 安装 Playwright

```bash
npm init playwright@latest
```

选择配置：
- TypeScript / JavaScript
- 测试目录：`tests/e2e`
- 是否安装浏览器：是

### 配置文件 playwright.config.ts

```typescript
import { defineConfig, devices } from '@playwright/test'

export default defineConfig({
  testDir: './tests/e2e',
  fullyParallel: true,
  forbidOnly: !!process.env.CI,
  retries: process.env.CI ? 2 : 0,
  workers: process.env.CI ? 1 : undefined,
  reporter: [
    ['html', { open: 'never' }],
    ['list'],
  ],
  use: {
    baseURL: 'http://localhost:3000',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
  },

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] },
    },
    {
      name: 'firefox',
      use: { ...devices['Desktop Firefox'] },
    },
    {
      name: 'webkit',
      use: { ...devices['Desktop Safari'] },
    },
    {
      name: 'mobile-chrome',
      use: { ...devices['Pixel 5'] },
    },
  ],

  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:3000',
    reuseExistingServer: !process.env.CI,
    timeout: 120000,
  },
})
```

---

## 测试用例组织规范

### 目录结构

```
tests/e2e/
├── fixtures/              # 测试夹具（全局设置）
│   └── auth.setup.ts     # 登录状态复用
├── pages/                 # Page Object 模式
│   ├── LoginPage.ts      # 登录页
│   ├── HomePage.ts       # 首页
│   ├── ProductPage.ts    # 商品页
│   ├── CartPage.ts       # 购物车页
│   └── CheckoutPage.ts   # 结算页
├── auth/                  # 认证相关测试
│   └── login.spec.ts
├── shopping/              # 购物流程测试
│   ├── browse-products.spec.ts
│   ├── add-to-cart.spec.ts
│   └── checkout.spec.ts
└── user/                  # 用户中心测试
    └── profile.spec.ts
```

### 测试命名规范

- **测试文件**：`{功能模块}.spec.ts`
- **测试用例**：`{用户角色} 应该 {做什么} 当 {什么条件}`

---

## Page Object 模式示例

### 登录页面封装

```typescript
// tests/e2e/pages/LoginPage.ts
import { Page, expect } from '@playwright/test'

export class LoginPage {
  constructor(private readonly page: Page) {}

  /** 导航到登录页 */
  async goto() {
    await this.page.goto('/login')
  }

  /** 输入用户名 */
  async fillUsername(username: string) {
    await this.page.getByLabel(/用户名|账号/).fill(username)
  }

  /** 输入密码 */
  async fillPassword(password: string) {
    await this.page.getByLabel(/密码/).fill(password)
  }

  /** 点击登录按钮 */
  async submit() {
    await this.page.getByRole('button', { name: /登录|登/ }).click()
  }

  /** 快捷登录 */
  async login(username: string, password: string) {
    await this.fillUsername(username)
    await this.fillPassword(password)
    await this.submit()
  }

  /** 断言登录成功 */
  async assertLoginSuccess() {
    await expect(this.page).toHaveURL(/\/dashboard|\/home/)
    await expect(this.page.getByRole('button', { name: /退出|登出/ })).toBeVisible()
  }

  /** 断言错误消息 */
  async assertErrorMessage(message: string) {
    await expect(this.page.getByText(message)).toBeVisible()
  }
}
```

### 商品页面封装

```typescript
// tests/e2e/pages/ProductPage.ts
import { Page, expect } from '@playwright/test'

export class ProductPage {
  constructor(private readonly page: Page) {}

  async gotoProductList() {
    await this.page.goto('/products')
  }

  /** 搜索商品 */
  async search(keyword: string) {
    await this.page.getByPlaceholder(/搜索/).fill(keyword)
    await this.page.getByPlaceholder(/搜索/).press('Enter')
  }

  /** 选择第一个商品 */
  async selectFirstProduct() {
    await this.page.getByRole('link', { name: /详情|查看/ }).first().click()
  }

  /** 添加到购物车 */
  async addToCart(quantity: number = 1) {
    if (quantity > 1) {
      await this.page.getByLabel(/数量/).fill(String(quantity))
    }
    await this.page.getByRole('button', { name: /加入购物车/ }).click()
  }

  /** 断言添加成功 */
  async assertAddToCartSuccess() {
    await expect(this.page.getByText(/已加入购物车|添加成功/)).toBeVisible()
  }
}
```

### 购物车页面封装

```typescript
// tests/e2e/pages/CartPage.ts
import { Page, expect } from '@playwright/test'

export class CartPage {
  constructor(private readonly page: Page) {}

  async goto() {
    await this.page.goto('/cart')
  }

  /** 获取商品数量 */
  async getItemCount() {
    const items = await this.page.getByRole('listitem').count()
    return items
  }

  /** 修改商品数量 */
  async updateQuantity(productName: string, quantity: number) {
    const item = this.page.getByRole('listitem').filter({ hasText: productName })
    await item.getByLabel(/数量/).fill(String(quantity))
    await item.getByRole('button', { name: /更新/ }).click()
  }

  /** 删除商品 */
  async removeItem(productName: string) {
    const item = this.page.getByRole('listitem').filter({ hasText: productName })
    await item.getByRole('button', { name: /删除/ }).click()
  }

  /** 去结算 */
  async gotoCheckout() {
    await this.page.getByRole('button', { name: /去结算|立即支付/ }).click()
  }

  /** 断言购物车有商品 */
  async assertHasItems() {
    await expect(this.page.getByRole('listitem').first()).toBeVisible()
  }

  /** 断言购物车为空 */
  async assertEmpty() {
    await expect(this.page.getByText(/购物车为空|暂无商品/)).toBeVisible()
  }
}
```

---

## 测试用例示例

### 示例一：登录功能测试

```typescript
// tests/e2e/auth/login.spec.ts
import { test, expect } from '@playwright/test'
import { LoginPage } from '../pages/LoginPage'

test.describe('用户登录功能', () => {
  let loginPage: LoginPage

  test.beforeEach(async ({ page }) => {
    loginPage = new LoginPage(page)
    await loginPage.goto()
  })

  test('正常场景 - 正确的账号密码应该登录成功', async () => {
    await loginPage.login('user@example.com', 'Test@123456')
    await loginPage.assertLoginSuccess()
  })

  test('参数校验 - 密码错误应该登录失败', async () => {
    await loginPage.login('user@example.com', 'WrongPassword')
    await loginPage.assertErrorMessage('密码错误')
  })

  test('参数校验 - 用户名为空应该提示错误', async () => {
    await loginPage.fillPassword('Test@123456')
    await loginPage.submit()
    await loginPage.assertErrorMessage('请输入用户名')
  })

  test('参数校验 - 账号不存在应该提示错误', async () => {
    await loginPage.login('not-exist@example.com', 'Test@123456')
    await loginPage.assertErrorMessage('账号不存在')
  })

  test('安全场景 - 连续5次失败应该锁定账号', async () => {
    // 连续失败5次
    for (let i = 0; i < 5; i++) {
      await loginPage.login('user@example.com', 'WrongPassword')
      await loginPage.assertErrorMessage('密码错误')
    }

    // 第6次应该提示锁定
    await loginPage.login('user@example.com', 'WrongPassword')
    await loginPage.assertErrorMessage('账号已锁定')
  })

  test('交互 - 显示/隐藏密码切换应该正常', async ({ page }) => {
    await loginPage.fillPassword('Test@123456')
    
    // 点击显示密码
    await page.getByRole('button', { name: /显示|查看/ }).click()
    await expect(page.getByLabel(/密码/)).toHaveAttribute('type', 'text')
    
    // 点击隐藏密码
    await page.getByRole('button', { name: /隐藏/ }).click()
    await expect(page.getByLabel(/密码/)).toHaveAttribute('type', 'password')
  })
})
```

### 示例二：购物完整流程测试

```typescript
// tests/e2e/shopping/checkout.spec.ts
import { test, expect } from '@playwright/test'
import { LoginPage } from '../pages/LoginPage'
import { ProductPage } from '../pages/ProductPage'
import { CartPage } from '../pages/CartPage'

test.describe('购物完整流程', () => {
  test.use({ storageState: 'storageState.json' }) // 使用已登录状态

  let productPage: ProductPage
  let cartPage: CartPage

  test.beforeEach(async ({ page }) => {
    productPage = new ProductPage(page)
    cartPage = new CartPage(page)
  })

  test('完整购物流程 - 浏览商品 → 加入购物车 → 结算支付', async ({ page }) => {
    // 步骤1: 浏览搜索商品
    await productPage.gotoProductList()
    await productPage.search('手机')

    // 步骤2: 查看商品详情
    await productPage.selectFirstProduct()
    await expect(page.getByText(/商品详情/)).toBeVisible()

    // 步骤3: 添加到购物车
    await productPage.addToCart(2)
    await productPage.assertAddToCartSuccess()

    // 步骤4: 进入购物车确认
    await cartPage.goto()
    await cartPage.assertHasItems()
    expect(await cartPage.getItemCount()).toBeGreaterThan(0)

    // 步骤5: 去结算
    await cartPage.gotoCheckout()
    await expect(page).toHaveURL(/\/checkout|\/order/)

    // 步骤6: 填写收货地址并提交订单
    await page.getByLabel(/收货人/).fill('张三')
    await page.getByLabel(/手机号/).fill('13800000000')
    await page.getByLabel(/地址/).fill('北京市朝阳区xxx街道')
    await page.getByRole('button', { name: /提交订单/ }).click()

    // 步骤7: 断言订单创建成功
    await expect(page.getByText(/订单提交成功|订单号/)).toBeVisible()
    const orderNo = await page.getByText(/订单号：|Order No/).textContent()
    expect(orderNo).toBeTruthy()
  })

  test('购物车管理 - 修改商品数量、删除商品应该正常', async () => {
    // 准备数据：先添加商品
    await productPage.gotoProductList()
    await productPage.selectFirstProduct()
    await productPage.addToCart(1)

    // 进入购物车
    await cartPage.goto()

    // 修改数量
    await cartPage.updateQuantity('测试商品', 3)
    await expect(cartPage.page.getByText('3')).toBeVisible()

    // 删除商品
    await cartPage.removeItem('测试商品')
    await cartPage.assertEmpty()
  })
})
```

### 示例三：认证状态复用 Fixture

```typescript
// tests/e2e/fixtures/auth.setup.ts
import { test as setup } from '@playwright/test'
import { LoginPage } from '../pages/LoginPage'

const authFile = 'storageState.json'

setup('登录并保存认证状态', async ({ page }) => {
  const loginPage = new LoginPage(page)
  await loginPage.goto()
  await loginPage.login('user@example.com', 'Test@123456')

  // 等待页面跳转完成
  await page.waitForURL(/\/dashboard|\/home/)

  // 保存认证状态
  await page.context().storageState({ path: authFile })
})
```

---

## 运行测试

```bash
# 运行所有测试
npx playwright test

# 运行特定测试文件
npx playwright test tests/e2e/auth/login.spec.ts

# 运行特定浏览器
npx playwright test --project=chromium

#  headed 模式（显示浏览器窗口）
npx playwright test --headed

# 调试模式
npx playwright test --debug

# 生成测试报告
npx playwright show-report
```

---

## 测试用例设计最佳实践

### 1. 用例分层原则

| 层级 | 说明 | 示例 |
|------|------|------|
| **P0 核心流程** | 冒烟测试，覆盖最核心业务 | 登录成功、下单成功、支付成功 |
| **P1 主要功能** | 主要功能点的正常+异常 | 登录失败场景、购物车增删改 |
| **P2 边缘场景** | 边界条件、特殊场景 | 网络异常、并发操作 |
| **P3 UI/交互** | 页面展示、交互细节 | 表单校验、按钮状态 |

### 2. 用例设计要点

1. **独立性**：每个用例可独立运行，不依赖其他用例
2. **可重复**：每次运行结果一致，无随机性
3. **原子性**：一个用例只验证一个功能点
4. **可读性**：用例描述清晰，步骤明确
5. **可维护性**：使用 Page Object 模式，减少重复代码

### 3. 断言最佳实践

- ✅ **断言状态，不要断言实现**
- ✅ **使用角色定位**：`getByRole`, `getByLabel`, `getByText`
- ✅ **避免 CSS 选择器**：页面重构后测试不失效
- ✅ **业务语义断言**：断言用户看到的结果
- ✅ **等待网络请求**：不要硬编码 `waitForTimeout`

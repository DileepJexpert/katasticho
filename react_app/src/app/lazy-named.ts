import { lazy, type ComponentType, type LazyExoticComponent } from 'react'

type ModuleExports = Record<string, unknown>

export function resolveNamedComponent(
  module: ModuleExports,
  exportName: string,
): ComponentType {
  const component = module[exportName]

  if (typeof component !== 'function') {
    throw new Error(`Lazy route export "${exportName}" is not a React component.`)
  }

  return component as ComponentType
}

/** Lazily loads a named page export while preserving React Router's element API. */
export function lazyNamed(
  loader: () => Promise<ModuleExports>,
  exportName: string,
): LazyExoticComponent<ComponentType> {
  return lazy(async () => {
    const module = await loader()
    return { default: resolveNamedComponent(module, exportName) }
  })
}

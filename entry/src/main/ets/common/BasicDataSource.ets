// Basic implementation of IDataSource to handle data listener
export class BasicDataSource<T> implements IDataSource {
  protected listeners: DataChangeListener[] = [];

  public totalCount(): number {
    return 0;
  }

  public getData(index: number): T {
    return '' as T;
  }

  // 该方法为框架侧调用，为LazyForEach组件向其数据源处添加listener监听
  registerDataChangeListener(listener: DataChangeListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  // 该方法为框架侧调用，为对应的LazyForEach组件在数据源处去除listener监听
  unregisterDataChangeListener(listener: DataChangeListener): void {
    const pos = this.listeners.indexOf(listener);
    if (pos >= 0) {
      this.listeners.splice(pos, 1);
    }
  }

  // 通知LazyForEach组件需要重载所有子组件
  notifyDataReload(): void {
    this.listeners.forEach(listener => {
      listener.onDataReloaded();
    })
  }

  // 通知LazyForEach组件需要在index对应索引处添加子组件
  notifyDataAdd(index: number): void {
    this.listeners.forEach(listener => {
      listener.onDataAdd(index);
    })
  }

  // 通知LazyForEach组件在index对应索引处数据有变化，需要重建该子组件
  notifyDataChange(index: number): void {
    this.listeners.forEach(listener => {
      listener.onDataChange(index);
    })
  }

  // 通知LazyForEach组件需要在index对应索引处删除该子组件
  notifyDataDelete(index: number): void {
    this.listeners.forEach(listener => {
      listener.onDataDelete(index);
    })
  }

  // 通知LazyForEach组件将from索引和to索引处的子组件进行交换
  notifyDataMove(from: number, to: number): void {
    this.listeners.forEach(listener => {
      listener.onDataMove(from, to);
    })
  }
}

export class ArrayDataSource<T> extends BasicDataSource<T> {
  protected data: T[] = []

  constructor() {
    super()
  }

  public totalCount(): number {
    return this.data.length
  }

  public getData(index: number): T {
    return this.data[index]
  }

  public reload(data: T[]) {
    this.data = data
    this.notifyDataReload()
    return this
  }
}

export abstract class DbPageDataSource<T> extends BasicDataSource<T> {
  private data: T[] = []
  protected pageSize = 100
  protected threshold = 5
  private hasMore: boolean = true

  constructor() {
    super()
  }

  public totalCount(): number {
    return this.data.length
  }

  protected abstract queryDatabase(offset: number, size: number): Promise<T[]>

  private querying: boolean = false

  public getData(index: number): T {
    if (this.totalCount() % this.pageSize == 0 && this.totalCount() - index < this.threshold && this.hasMore &&
      !this.querying) {
      this.querying = true
      this.queryDatabase(this.totalCount(), this.pageSize).then(data => {
        if (data.length == 0) {
          this.hasMore = false
        } else {
          this.data = this.data.concat(data)
          this.notifyDataReload()
        }
        this.querying = false
      })
    }
    return this.data[index]
  }

  public async reload(): Promise<number> {
    const data = await this.queryDatabase(0, this.pageSize)
    if (data) {
      this.data = data
      this.notifyDataReload()
    }
    return this.data.length
  }
}

export class ReloadController {
  reload = (): void => {
  }
}
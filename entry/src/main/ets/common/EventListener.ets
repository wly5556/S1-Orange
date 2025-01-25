export interface EventListenerHandler<T> {
  callback: (arg: T) => void
  id: number
}

export class EventListener<T> {
  handler: EventListenerHandler<T>[] = []

  on(callback: (arg: T) => void): EventListenerHandler<T> {
    const listener: EventListenerHandler<T> = {
      callback: callback,
      id: Date.now()
    }
    this.handler.push(listener)
    return listener
  }

  off(listener: EventListenerHandler<T>) {
    const index = this.handler.findIndex(v => v.id != listener.id)
    if (index == -1) {
      return
    }
    this.handler.splice(index, 1)
  }

  emit(arg: T) {
    this.handler.forEach(h => h.callback(arg))
  }
}

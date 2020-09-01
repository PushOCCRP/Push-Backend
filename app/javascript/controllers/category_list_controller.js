import { Controller } from 'stimulus';
import { v4 as uuidv4 } from 'uuid';

export default class extends Controller {
  static targets = [ "categories" ]

  connect() {
    console.log("hello from StimulusJS")
  }

  add() {
    let uuid = uuidv4()
    let categoryInput = `
    <div>
      <input data-target="category-list.update" data-id="${uuid}" type="text">
      <button data-target="category-list.remove" data-id="${uuid}">X</button>
      <br>
    </div>
    `

    this.categoriesTarget.innerHTML += categoryInput
  }

  remove() {
    this.event.target.parent.remove()
  }

  update() {
    let updatedCategories = this.categories
    updatedCategories[this.event.target.data.id] = this.event.target.value
    this.data.set('categories', updatedCategories)
  }

  categories() {
    this.data.get('categories')
  }
}

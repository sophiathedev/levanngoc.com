// Initialize highlight.js and generate default schema preview
document.addEventListener('DOMContentLoaded', function() {
  // Generate schema based on current form values
  generateSchema();
});

// Toggle schema form based on selected type
function toggleSchemaForm(schemaType) {
  // Hide all forms first
  const allForms = document.querySelectorAll('[id$="-form"]');
  allForms.forEach(form => {
    form.style.display = 'none';
  });

  // Show the selected form if it exists
  const formId = schemaType.toLowerCase() + '-form';
  const selectedForm = document.getElementById(formId);
  if (selectedForm) {
    selectedForm.style.display = 'block';
  } else {
    // If form doesn't exist yet, show a message or keep all hidden
    console.log('Form for ' + schemaType + ' not implemented yet');
  }

  // Auto-generate schema preview when switching types
  generateSchema();
}

// Counter for image URL IDs
let imageUrlCounter = 1;

// Add new image URL row
function addImageUrl() {
  imageUrlCounter++;
  const container = document.getElementById('image-urls-container');
  const newRow = document.createElement('div');
  newRow.className = 'flex items-end gap-3 image-url-row';
  newRow.setAttribute('data-id', imageUrlCounter);

  newRow.innerHTML = `
    <div class="form-control flex-1">
      <label class="label py-1">
        <span class="label-text text-sm">Images URL ${imageUrlCounter}</span>
      </label>
      <input
        type="url"
        placeholder="URL"
        class="input input-bordered w-full article-image-url"
        oninput="generateSchema()"
      />
    </div>
    <button
      type="button"
      onclick="removeImageUrl(${imageUrlCounter})"
      class="btn btn-ghost btn-sm btn-square text-error mb-1"
    >
      <svg
        xmlns="http://www.w3.org/2000/svg"
        fill="none"
        viewBox="0 0 24 24"
        stroke-width="1.5"
        stroke="currentColor"
        class="w-5 h-5"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          d="m14.74 9-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 0 1-2.244 2.077H8.084a2.25 2.25 0 0 1-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 0 0-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 0 1 3.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 0 0-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 0 0-7.5 0"
        />
      </svg>
    </button>
  `;

  container.appendChild(newRow);
}

// Remove image URL row
function removeImageUrl(id) {
  const container = document.getElementById('image-urls-container');
  const rows = container.querySelectorAll('.image-url-row');

  // Don't allow removing if only one row remains
  if (rows.length > 1) {
    const rowToRemove = container.querySelector(`[data-id="${id}"]`);
    if (rowToRemove) {
      rowToRemove.remove();
      generateSchema();
    }
  }
}

// Counter for breadcrumb items
let breadcrumbCounter = 2;

// Add new breadcrumb item
function addBreadcrumbItem() {
  breadcrumbCounter++;
  const container = document.getElementById('breadcrumb-items-container');
  const newItem = document.createElement('div');
  newItem.className = 'breadcrumb-item';
  newItem.setAttribute('data-id', breadcrumbCounter);

  newItem.innerHTML = `
    <h4 class="font-medium">Tên Page #${breadcrumbCounter}</h4>
    <div class="flex items-end gap-3">
      <div class="form-control" style="flex: 0 0 300px;">
        <input
          type="text"
          placeholder="Nhập tên page #${breadcrumbCounter}"
          class="input input-bordered w-full breadcrumb-name"
          oninput="generateSchema()"
        />
      </div>
      <div class="form-control flex-1">
        <input
          type="url"
          placeholder="URL"
          class="input input-bordered w-full breadcrumb-url"
          oninput="generateSchema()"
        />
      </div>
      <button
        type="button"
        onclick="removeBreadcrumbItem(${breadcrumbCounter})"
        class="btn btn-ghost btn-sm btn-square text-error mb-1"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          fill="none"
          viewBox="0 0 24 24"
          stroke-width="1.5"
          stroke="currentColor"
          class="w-5 h-5"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            d="m14.74 9-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 0 1-2.244 2.077H8.084a2.25 2.25 0 0 1-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 0 0-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 0 1 3.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 0 0-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 0 0-7.5 0"
          />
        </svg>
      </button>
    </div>
  `;

  container.appendChild(newItem);
}

// Remove breadcrumb item
function removeBreadcrumbItem(id) {
  const container = document.getElementById('breadcrumb-items-container');
  const items = container.querySelectorAll('.breadcrumb-item');

  // Don't allow removing if only one item remains
  if (items.length > 1) {
    const itemToRemove = container.querySelector(`[data-id="${id}"]`);
    if (itemToRemove) {
      itemToRemove.remove();
      generateSchema();
    }
  }
}

// Counter for tickets
let ticketCounter = 1;

// Add new ticket
function addTicket() {
  ticketCounter++;
  const container = document.getElementById('tickets-container');
  const newTicket = document.createElement('div');
  newTicket.className = 'border border-base-300 rounded-lg p-4 relative ticket-item';
  newTicket.setAttribute('data-id', ticketCounter);

  newTicket.innerHTML = `
    <button
      type="button"
      onclick="removeTicket(${ticketCounter})"
      class="btn btn-ghost btn-sm btn-square absolute top-2 right-2"
    >
      <svg
        xmlns="http://www.w3.org/2000/svg"
        fill="none"
        viewBox="0 0 24 24"
        stroke-width="1.5"
        stroke="currentColor"
        class="w-5 h-5"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          d="M6 18 18 6M6 6l12 12"
        />
      </svg>
    </button>

    <div class="grid grid-cols-1 lg:grid-cols-3 gap-4">
      <div class="form-control">
        <label class="label">
          <span class="label-text">Name</span>
        </label>
        <input type="text" placeholder="Nhập tên" class="input input-bordered w-full ticket-name" oninput="generateSchema()" />
      </div>
      <div class="form-control">
        <label class="label">
          <span class="label-text">Price</span>
        </label>
        <input type="number" placeholder="Nhập giá" class="input input-bordered w-full ticket-price" oninput="generateSchema()" />
      </div>
      <div class="form-control">
        <label class="label">
          <span class="label-text">Available from</span>
        </label>
        <input type="date" placeholder="Select date" class="input input-bordered w-full ticket-valid-from" oninput="generateSchema()" />
      </div>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-2 gap-4 mt-4">
      <div class="form-control">
        <label class="label">
          <span class="label-text">URL</span>
        </label>
        <input type="url" placeholder="Nhập URL" class="input input-bordered w-full ticket-url" oninput="generateSchema()" />
      </div>
      <div class="form-control">
        <label class="label">
          <span class="label-text">Availability</span>
        </label>
        <select class="select select-bordered w-full ticket-availability" onchange="generateSchema()">
          <option value="">Availability</option>
          <option value="InStock">InStock</option>
          <option value="SoldOut">SoldOut</option>
          <option value="PreOrder">PreOrder</option>
        </select>
      </div>
    </div>
  `;

  container.appendChild(newTicket);
  updateTicketDeleteButtons();
}

// Remove ticket
function removeTicket(id) {
  const container = document.getElementById('tickets-container');
  const ticketToRemove = container.querySelector(`[data-id="${id}"]`);
  if (ticketToRemove) {
    ticketToRemove.remove();
    generateSchema();
  }
}

// Update visibility of delete buttons for tickets
function updateTicketDeleteButtons() {
  const container = document.getElementById('tickets-container');
  const deleteButtons = container.querySelectorAll('.ticket-item button[onclick^="removeTicket"]');

  // Always show delete buttons, allowing deletion of all tickets
  deleteButtons.forEach(button => {
    button.style.display = 'block';
  });
}

// Counter for FAQ items
let faqCounter = 0;

// Update FAQ bottom button visibility
function updateFaqBottomButton() {
  const container = document.getElementById('faq-items-container');
  const bottomButton = document.getElementById('faq-bottom-button');
  const items = container.querySelectorAll('.faq-item');

  if (bottomButton) {
    bottomButton.style.display = items.length >= 1 ? 'flex' : 'none';
  }
}

// Add new FAQ item
function addFaqItem() {
  faqCounter++;
  const container = document.getElementById('faq-items-container');
  const newItem = document.createElement('div');
  newItem.className = 'border border-base-300 rounded-lg p-4 relative faq-item';
  newItem.setAttribute('data-id', faqCounter);

  newItem.innerHTML = `
    <div class="flex justify-between items-center mb-3">
      <h4 class="font-medium">Câu hỏi ${faqCounter}</h4>
      <button
        type="button"
        onclick="removeFaqItem(${faqCounter})"
        class="btn btn-ghost btn-sm btn-square text-error"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          fill="none"
          viewBox="0 0 24 24"
          stroke-width="1.5"
          stroke="currentColor"
          class="w-5 h-5"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            d="m14.74 9-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 0 1-2.244 2.077H8.084a2.25 2.25 0 0 1-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 0 0-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 0 1 3.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 0 0-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 0 0-7.5 0"
          />
        </svg>
      </button>
    </div>

    <div class="form-control mb-4">
      <input
        type="text"
        placeholder="Câu hỏi"
        class="input input-bordered w-full faq-question"
        oninput="generateSchema()"
      />
    </div>

    <div class="form-control">
      <label class="label">
        <span class="label-text">Câu trả lời ${faqCounter}</span>
      </label>
      <textarea
        placeholder="Câu Trả lời"
        class="textarea textarea-bordered w-full h-32 faq-answer"
        oninput="generateSchema()"
      ></textarea>
    </div>
  `;

  container.appendChild(newItem);
  updateFaqBottomButton();
}

// Remove FAQ item
function removeFaqItem(id) {
  const container = document.getElementById('faq-items-container');
  const itemToRemove = container.querySelector(`[data-id="${id}"]`);
  if (itemToRemove) {
    itemToRemove.remove();
    updateFaqBottomButton();
    generateSchema();
  }
}

// Counter for HowTo supplies
let supplyCounter = 0;

// Add new supply
function addSupply() {
  supplyCounter++;
  const container = document.getElementById('supply-container');
  const newSupply = document.createElement('div');
  newSupply.className = 'flex items-center gap-2 supply-item';
  newSupply.setAttribute('data-id', supplyCounter);

  newSupply.innerHTML = `
    <input
      type="text"
      placeholder="supply #${supplyCounter}"
      class="input input-bordered w-full supply-name"
      oninput="generateSchema()"
    />
    <button
      type="button"
      onclick="removeSupply(${supplyCounter})"
      class="btn btn-ghost btn-sm btn-square text-error"
    >
      <svg
        xmlns="http://www.w3.org/2000/svg"
        fill="none"
        viewBox="0 0 24 24"
        stroke-width="1.5"
        stroke="currentColor"
        class="w-5 h-5"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          d="m14.74 9-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 0 1-2.244 2.077H8.084a2.25 2.25 0 0 1-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 0 0-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 0 1 3.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 0 0-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 0 0-7.5 0"
        />
      </svg>
    </button>
  `;

  container.appendChild(newSupply);
}

// Remove supply
function removeSupply(id) {
  const container = document.getElementById('supply-container');
  const itemToRemove = container.querySelector(`[data-id="${id}"]`);
  if (itemToRemove) {
    itemToRemove.remove();
    generateSchema();
  }
}

// Counter for HowTo tools
let toolCounter = 0;

// Add new tool
function addTool() {
  toolCounter++;
  const container = document.getElementById('tool-container');
  const newTool = document.createElement('div');
  newTool.className = 'flex items-center gap-2 tool-item';
  newTool.setAttribute('data-id', toolCounter);

  newTool.innerHTML = `
    <input
      type="text"
      placeholder="tool #${toolCounter}"
      class="input input-bordered w-full tool-name"
      oninput="generateSchema()"
    />
    <button
      type="button"
      onclick="removeTool(${toolCounter})"
      class="btn btn-ghost btn-sm btn-square text-error"
    >
      <svg
        xmlns="http://www.w3.org/2000/svg"
        fill="none"
        viewBox="0 0 24 24"
        stroke-width="1.5"
        stroke="currentColor"
        class="w-5 h-5"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          d="m14.74 9-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 0 1-2.244 2.077H8.084a2.25 2.25 0 0 1-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 0 0-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 0 1 3.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 0 0-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 0 0-7.5 0"
        />
      </svg>
    </button>
  `;

  container.appendChild(newTool);
}

// Remove tool
function removeTool(id) {
  const container = document.getElementById('tool-container');
  const itemToRemove = container.querySelector(`[data-id="${id}"]`);
  if (itemToRemove) {
    itemToRemove.remove();
    generateSchema();
  }
}

// Counter for HowTo steps
let stepCounter = 1;

// Add new step
function addStep() {
  stepCounter++;
  const container = document.getElementById('steps-container');
  const newStep = document.createElement('div');
  newStep.className = 'border border-base-300 rounded-lg p-4 step-item';
  newStep.setAttribute('data-id', stepCounter);

  newStep.innerHTML = `
    <h4 class="font-medium mb-4">Step #${stepCounter}: Instruction</h4>

    <div class="form-control mb-4">
      <textarea
        placeholder="Hướng dẫn"
        class="textarea textarea-bordered w-full h-24 step-instruction"
        oninput="generateSchema()"
      ></textarea>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-3 gap-4">
      <div class="form-control">
        <label class="label">
          <span class="label-text">Image Url</span>
        </label>
        <input type="url" placeholder="Nhập URL" class="input input-bordered w-full step-image" oninput="generateSchema()" />
      </div>
      <div class="form-control">
        <label class="label">
          <span class="label-text">Name</span>
        </label>
        <input type="text" placeholder="Nhập tên" class="input input-bordered w-full step-name" oninput="generateSchema()" />
      </div>
      <div class="form-control">
        <label class="label">
          <span class="label-text">URL</span>
        </label>
        <input type="url" placeholder="Nhập URL" class="input input-bordered w-full step-url" oninput="generateSchema()" />
      </div>
    </div>

    <button
      type="button"
      onclick="removeStep(${stepCounter})"
      class="btn btn-error btn-sm mt-4"
    >
      Xóa Step
    </button>
  `;

  container.appendChild(newStep);
}

// Remove step
function removeStep(id) {
  const container = document.getElementById('steps-container');
  const steps = container.querySelectorAll('.step-item');

  // Don't allow removing if only one step remains
  if (steps.length > 1) {
    const itemToRemove = container.querySelector(`[data-id="${id}"]`);
    if (itemToRemove) {
      itemToRemove.remove();
      generateSchema();
    }
  }
}

// Counter for main opening hours
let mainOpeningHourCounter = 0;

// Add main opening hour
function addMainOpeningHour() {
  mainOpeningHourCounter++;
  const container = document.getElementById('main-opening-hours-container');
  const newHour = document.createElement('div');
  newHour.className = 'border border-base-300 rounded-lg p-4 main-opening-hour-item';
  newHour.setAttribute('data-id', mainOpeningHourCounter);

  newHour.innerHTML = `
    <div class="grid grid-cols-1 lg:grid-cols-4 gap-4 items-end">
      <div class="form-control lg:col-span-1">
        <label class="label">
          <span class="label-text">Day(s) of the week</span>
        </label>
        <select class="select select-bordered w-full main-opening-day" onchange="generateSchema()">
          <option value="">Chọn ngày</option>
          <option value="Sunday">Chủ nhật</option>
          <option value="Monday">Thứ 2</option>
          <option value="Tuesday">Thứ 3</option>
          <option value="Wednesday">Thứ 4</option>
          <option value="Thursday">Thứ 5</option>
          <option value="Friday">Thứ 6</option>
          <option value="Saturday">Thứ 7</option>
        </select>
      </div>
      <div class="form-control">
        <label class="label">
          <span class="label-text">Opens at (e.g. 08:00)</span>
        </label>
        <input type="time" placeholder="Giờ mở cửa" class="input input-bordered w-full main-opening-opens" oninput="generateSchema()" />
      </div>
      <div class="form-control">
        <label class="label">
          <span class="label-text">Closes at (e.g. 21:00)</span>
        </label>
        <input type="time" placeholder="Giờ đóng cửa" class="input input-bordered w-full main-opening-closes" oninput="generateSchema()" />
      </div>
      <div class="form-control">
        <button
          type="button"
          onclick="removeMainOpeningHour(${mainOpeningHourCounter})"
          class="btn btn-ghost btn-sm btn-square text-error"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            fill="none"
            viewBox="0 0 24 24"
            stroke-width="1.5"
            stroke="currentColor"
            class="w-5 h-5"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="m14.74 9-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 0 1-2.244 2.077H8.084a2.25 2.25 0 0 1-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 0 0-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 0 1 3.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 0 0-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 0 0-7.5 0"
            />
          </svg>
        </button>
      </div>
    </div>
  `;

  container.appendChild(newHour);
}

// Remove main opening hour
function removeMainOpeningHour(id) {
  const container = document.getElementById('main-opening-hours-container');
  const itemToRemove = container.querySelector(`[data-id="${id}"]`);
  if (itemToRemove) {
    itemToRemove.remove();
  }
}

// Counter for departments
let departmentCounter = 0;

// Add department
function addDepartment() {
  departmentCounter++;
  const container = document.getElementById('departments-container');
  const newDept = document.createElement('div');
  newDept.className = 'border border-base-300 rounded-lg p-4 department-item bg-base-200';
  newDept.setAttribute('data-id', departmentCounter);

  newDept.innerHTML = `
    <div class="flex items-end gap-3 mb-4">
      <div class="form-control flex-1">
        <label class="label">
          <span class="label-text font-medium">LocalBusiness @type</span>
        </label>
        <select class="select select-bordered w-full department-type" onchange="generateSchema()">
        <option value="LocalBusiness" selected>LocalBusiness</option>
        <option value="AnimalShelter">AnimalShelter</option>
        <option value="ArchiveOrganization">ArchiveOrganization</option>
        <option value="AutomotiveBusiness">AutomotiveBusiness</option>
        <option value="ChildCare">ChildCare</option>
        <option value="Dentist">Dentist</option>
        <option value="DryCleaningOrLaundry">DryCleaningOrLaundry</option>
        <option value="EmergencyService">EmergencyService</option>
        <option value="EmploymentAgency">EmploymentAgency</option>
        <option value="EntertainmentBusiness">EntertainmentBusiness</option>
        <option value="FinancialService">FinancialService</option>
        <option value="FoodEstablishment">FoodEstablishment</option>
        <option value="GovernmentOffice">GovernmentOffice</option>
        <option value="HealthAndBeautyBusiness">HealthAndBeautyBusiness</option>
        <option value="HomeAndConstructionBusiness">HomeAndConstructionBusiness</option>
        <option value="InternetCafe">InternetCafe</option>
        <option value="LegalService">LegalService</option>
        <option value="Library">Library</option>
        <option value="LodgingBusiness">LodgingBusiness</option>
        <option value="MedicalBusiness">MedicalBusiness</option>
        <option value="ProfessionalService">ProfessionalService</option>
        <option value="RadioStation">RadioStation</option>
        <option value="RealEstateAgent">RealEstateAgent</option>
        <option value="RecyclingCenter">RecyclingCenter</option>
        <option value="SelfStorage">SelfStorage</option>
        <option value="ShoppingCenter">ShoppingCenter</option>
        <option value="SportsActivityLocation">SportsActivityLocation</option>
        <option value="Store">Store</option>
        <option value="TelevisionStation">TelevisionStation</option>
        <option value="TouristInformationCenter">TouristInformationCenter</option>
        <option value="TravelAgency">TravelAgency</option>
      </select>
      </div>
      <button
        type="button"
        onclick="removeDepartment(${departmentCounter})"
        class="btn btn-ghost btn-sm btn-square text-error mb-1"
      >
        <svg
          xmlns="http://www.w3.org/2000/svg"
          fill="none"
          viewBox="0 0 24 24"
          stroke-width="1.5"
          stroke="currentColor"
          class="w-5 h-5"
        >
          <path
            stroke-linecap="round"
            stroke-linejoin="round"
            d="m14.74 9-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 0 1-2.244 2.077H8.084a2.25 2.25 0 0 1-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 0 0-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 0 1 3.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 0 0-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 0 0-7.5 0"
          />
        </svg>
      </button>
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-3 gap-4 mt-4">
      <div class="form-control">
        <label class="label">
          <span class="label-text font-medium">Name</span>
        </label>
        <input type="text" placeholder="Nhập tên" class="input input-bordered w-full department-name" oninput="generateSchema()" />
      </div>

      <div class="form-control">
        <label class="label">
          <span class="label-text font-medium">Image URL</span>
        </label>
        <input type="url" placeholder="URL" class="input input-bordered w-full department-image" oninput="generateSchema()" />
      </div>

      <div class="form-control">
        <label class="label">
          <span class="label-text font-medium">Phone</span>
        </label>
        <input type="tel" placeholder="Nhập SĐT" class="input input-bordered w-full department-phone" oninput="generateSchema()" />
      </div>
    </div>

    <div class="mt-4">
      <button
        type="button"
        onclick="addDepartmentOpeningHour(${departmentCounter})"
        class="btn btn-primary btn-sm"
      >
        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-5 h-5">
          <path stroke-linecap="round" stroke-linejoin="round" d="M12 6v6h4.5m4.5 0a9 9 0 1 1-18 0 9 9 0 0 1 18 0Z" />
        </svg>
        Opening hours
      </button>

      <div id="dept-opening-hours-${departmentCounter}" class="space-y-4 mt-4">
      </div>
    </div>
  `;

  container.appendChild(newDept);
}

// Remove department
function removeDepartment(id) {
  const container = document.getElementById('departments-container');
  const itemToRemove = container.querySelector(`[data-id="${id}"]`);
  if (itemToRemove) {
    itemToRemove.remove();
  }
}

// Counter for department opening hours (keyed by department ID)
const deptOpeningHourCounters = {};

// Add opening hour to a specific department
function addDepartmentOpeningHour(deptId) {
  if (!deptOpeningHourCounters[deptId]) {
    deptOpeningHourCounters[deptId] = 0;
  }
  deptOpeningHourCounters[deptId]++;

  const container = document.getElementById(`dept-opening-hours-${deptId}`);
  const newHour = document.createElement('div');
  newHour.className = 'border border-base-300 rounded-lg p-4 dept-opening-hour-item';
  newHour.setAttribute('data-id', deptOpeningHourCounters[deptId]);

  newHour.innerHTML = `
    <div class="grid grid-cols-1 lg:grid-cols-4 gap-4 items-end">
      <div class="form-control lg:col-span-1">
        <label class="label">
          <span class="label-text">Day(s) of the week</span>
        </label>
        <select class="select select-bordered w-full dept-opening-day" onchange="generateSchema()">
          <option value="">Chọn ngày</option>
          <option value="Sunday">Chủ nhật</option>
          <option value="Monday">Thứ 2</option>
          <option value="Tuesday">Thứ 3</option>
          <option value="Wednesday">Thứ 4</option>
          <option value="Thursday">Thứ 5</option>
          <option value="Friday">Thứ 6</option>
          <option value="Saturday">Thứ 7</option>
        </select>
      </div>
      <div class="form-control">
        <label class="label">
          <span class="label-text">Opens at (e.g. 08:00)</span>
        </label>
        <input type="time" placeholder="Giờ mở cửa" class="input input-bordered w-full dept-opening-opens" oninput="generateSchema()" />
      </div>
      <div class="form-control">
        <label class="label">
          <span class="label-text">Closes at (e.g. 21:00)</span>
        </label>
        <input type="time" placeholder="Giờ đóng cửa" class="input input-bordered w-full dept-opening-closes" oninput="generateSchema()" />
      </div>
      <div class="form-control">
        <button
          type="button"
          onclick="removeDepartmentOpeningHour(${deptId}, ${deptOpeningHourCounters[deptId]})"
          class="btn btn-ghost btn-sm btn-square text-error"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            fill="none"
            viewBox="0 0 24 24"
            stroke-width="1.5"
            stroke="currentColor"
            class="w-5 h-5"
          >
            <path
              stroke-linecap="round"
              stroke-linejoin="round"
              d="m14.74 9-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 0 1-2.244 2.077H8.084a2.25 2.25 0 0 1-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 0 0-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 0 1 3.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 0 0-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 0 0-7.5 0"
            />
          </svg>
        </button>
      </div>
    </div>
  `;

  container.appendChild(newHour);
}

// Remove department opening hour
function removeDepartmentOpeningHour(deptId, hourId) {
  const container = document.getElementById(`dept-opening-hours-${deptId}`);
  const itemToRemove = container.querySelector(`[data-id="${hourId}"]`);
  if (itemToRemove) {
    itemToRemove.remove();
  }
}

// Counter for social profiles
let socialProfileCounter = 0;

// Available social platforms
const socialPlatforms = [
  { value: 'Facebook', label: 'Facebook', icon: 'facebook' },
  { value: 'Twitter', label: 'Twitter', icon: 'twitter' },
  { value: 'Instagram', label: 'Instagram', icon: 'instagram' },
  { value: 'YouTube', label: 'YouTube', icon: 'youtube' },
  { value: 'LinkedIn', label: 'LinkedIn', icon: 'linkedin' },
  { value: 'Pinterest', label: 'Pinterest', icon: 'pinterest' },
  { value: 'SoundCloud', label: 'SoundCloud', icon: 'soundcloud' },
  { value: 'Tumblr', label: 'Tumblr', icon: 'tumblr' }
];

// Get icon HTML for social platform
function getSocialIcon(platform) {
  const iconMap = {
    'instagram': '<svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24"><path d="M12 2.163c3.204 0 3.584.012 4.85.07 3.252.148 4.771 1.691 4.919 4.919.058 1.265.069 1.645.069 4.849 0 3.205-.012 3.584-.069 4.849-.149 3.225-1.664 4.771-4.919 4.919-1.266.058-1.644.07-4.85.07-3.204 0-3.584-.012-4.849-.07-3.26-.149-4.771-1.699-4.919-4.92-.058-1.265-.07-1.644-.07-4.849 0-3.204.013-3.583.07-4.849.149-3.227 1.664-4.771 4.919-4.919 1.266-.057 1.645-.069 4.849-.069zm0-2.163c-3.259 0-3.667.014-4.947.072-4.358.2-6.78 2.618-6.98 6.98-.059 1.281-.073 1.689-.073 4.948 0 3.259.014 3.668.072 4.948.2 4.358 2.618 6.78 6.98 6.98 1.281.058 1.689.072 4.948.072 3.259 0 3.668-.014 4.948-.072 4.354-.2 6.782-2.618 6.979-6.98.059-1.28.073-1.689.073-4.948 0-3.259-.014-3.667-.072-4.947-.196-4.354-2.617-6.78-6.979-6.98-1.281-.059-1.69-.073-4.949-.073zm0 5.838c-3.403 0-6.162 2.759-6.162 6.162s2.759 6.163 6.162 6.163 6.162-2.759 6.162-6.163c0-3.403-2.759-6.162-6.162-6.162zm0 10.162c-2.209 0-4-1.79-4-4 0-2.209 1.791-4 4-4s4 1.791 4 4c0 2.21-1.791 4-4 4zm6.406-11.845c-.796 0-1.441.645-1.441 1.44s.645 1.44 1.441 1.44c.795 0 1.439-.645 1.439-1.44s-.644-1.44-1.439-1.44z"/></svg>',
    'youtube': '<svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24"><path d="M23.498 6.186a3.016 3.016 0 0 0-2.122-2.136C19.505 3.545 12 3.545 12 3.545s-7.505 0-9.377.505A3.017 3.017 0 0 0 .502 6.186C0 8.07 0 12 0 12s0 3.93.502 5.814a3.016 3.016 0 0 0 2.122 2.136c1.871.505 9.376.505 9.376.505s7.505 0 9.377-.505a3.015 3.015 0 0 0 2.122-2.136C24 15.93 24 12 24 12s0-3.93-.502-5.814zM9.545 15.568V8.432L15.818 12l-6.273 3.568z"/></svg>',
    'linkedin': '<svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24"><path d="M20.447 20.452h-3.554v-5.569c0-1.328-.027-3.037-1.852-3.037-1.853 0-2.136 1.445-2.136 2.939v5.667H9.351V9h3.414v1.561h.046c.477-.9 1.637-1.85 3.37-1.85 3.601 0 4.267 2.37 4.267 5.455v6.286zM5.337 7.433c-1.144 0-2.063-.926-2.063-2.065 0-1.138.92-2.063 2.063-2.063 1.14 0 2.064.925 2.064 2.063 0 1.139-.925 2.065-2.064 2.065zm1.782 13.019H3.555V9h3.564v11.452zM22.225 0H1.771C.792 0 0 .774 0 1.729v20.542C0 23.227.792 24 1.771 24h20.451C23.2 24 24 23.227 24 22.271V1.729C24 .774 23.2 0 22.222 0h.003z"/></svg>',
    'pinterest': '<svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24"><path d="M12.017 0C5.396 0 .029 5.367.029 11.987c0 5.079 3.158 9.417 7.618 11.162-.105-.949-.199-2.403.041-3.439.219-.937 1.406-5.957 1.406-5.957s-.359-.72-.359-1.781c0-1.663.967-2.911 2.168-2.911 1.024 0 1.518.769 1.518 1.688 0 1.029-.653 2.567-.992 3.992-.285 1.193.6 2.165 1.775 2.165 2.128 0 3.768-2.245 3.768-5.487 0-2.861-2.063-4.869-5.008-4.869-3.41 0-5.409 2.562-5.409 5.199 0 1.033.394 2.143.889 2.741.099.12.112.225.085.345-.09.375-.293 1.199-.334 1.363-.053.225-.172.271-.401.165-1.495-.69-2.433-2.878-2.433-4.646 0-3.776 2.748-7.252 7.92-7.252 4.158 0 7.392 2.967 7.392 6.923 0 4.135-2.607 7.462-6.233 7.462-1.214 0-2.354-.629-2.758-1.379l-.749 2.848c-.269 1.045-1.004 2.352-1.498 3.146 1.123.345 2.306.535 3.55.535 6.607 0 11.985-5.365 11.985-11.987C23.97 5.39 18.592.026 11.985.026L12.017 0z"/></svg>',
    'facebook': '<svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24"><path d="M24 12.073c0-6.627-5.373-12-12-12s-12 5.373-12 12c0 5.99 4.388 10.954 10.125 11.854v-8.385H7.078v-3.47h3.047V9.43c0-3.007 1.792-4.669 4.533-4.669 1.312 0 2.686.235 2.686.235v2.953H15.83c-1.491 0-1.956.925-1.956 1.874v2.25h3.328l-.532 3.47h-2.796v8.385C19.612 23.027 24 18.062 24 12.073z"/></svg>',
    'twitter': '<svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24"><path d="M23.953 4.57a10 10 0 01-2.825.775 4.958 4.958 0 002.163-2.723c-.951.555-2.005.959-3.127 1.184a4.92 4.92 0 00-8.384 4.482C7.69 8.095 4.067 6.13 1.64 3.162a4.822 4.822 0 00-.666 2.475c0 1.71.87 3.213 2.188 4.096a4.904 4.904 0 01-2.228-.616v.06a4.923 4.923 0 003.946 4.827 4.996 4.996 0 01-2.212.085 4.936 4.936 0 004.604 3.417 9.867 9.867 0 01-6.102 2.105c-.39 0-.779-.023-1.17-.067a13.995 13.995 0 007.557 2.209c9.053 0 13.998-7.496 13.998-13.985 0-.21 0-.42-.015-.63A9.935 9.935 0 0024 4.59z"/></svg>',
    'soundcloud': '<svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24"><path d="M1.175 12.225c-.051 0-.094.046-.101.1l-.233 2.154.233 2.105c.007.058.05.098.101.098.05 0 .09-.04.099-.098l.255-2.105-.27-2.154c0-.057-.045-.1-.096-.1m-.899.828c-.06 0-.091.037-.104.094L0 14.479l.165 1.308c0 .055.045.094.09.094s.089-.045.104-.104l.21-1.319-.21-1.334c0-.061-.044-.09-.09-.09m1.83-1.229c-.061 0-.12.045-.12.104l-.21 2.563.225 2.458c0 .06.045.12.119.12.061 0 .105-.061.105-.12l.254-2.474-.254-2.548c-.016-.06-.061-.12-.135-.12m.973-.446c-.075 0-.135.06-.135.135l-.193 3.64.226 3.415c0 .074.06.134.134.134.074 0 .134-.06.134-.134l.27-3.445-.27-3.64c0-.074-.06-.134-.134-.134m1.008-.136c-.075 0-.15.074-.15.149l-.18 3.957.18 3.816c0 .074.075.149.15.149.074 0 .149-.074.149-.149l.209-3.816-.209-3.957c0-.074-.074-.149-.149-.149m.958 0c-.074 0-.149.074-.149.149l-.164 3.921.164 3.816c0 .074.074.149.149.149.074 0 .149-.074.149-.149l.195-3.816-.195-3.921c0-.074-.074-.149-.149-.149m.973.119c-.074 0-.149.06-.149.135l-.15 3.802.15 3.816c0 .074.074.134.149.134.074 0 .134-.06.134-.134l.179-3.816-.179-3.802c0-.074-.06-.135-.134-.135m.958-.119c-.075 0-.134.06-.134.134l-.15 3.921.15 3.816c0 .074.06.134.134.134.075 0 .15-.06.15-.134l.164-3.816-.164-3.921c0-.074-.075-.134-.15-.134m.959.134c-.09 0-.15.075-.15.15l-.134 3.787.134 3.801c0 .074.075.149.15.149.074 0 .149-.074.149-.149l.164-3.801-.164-3.787c0-.075-.074-.15-.149-.15m.973-.074c-.09 0-.149.074-.149.149l-.134 3.862.134 3.801c0 .074.074.149.149.149.089 0 .149-.074.149-.149l.149-3.801-.149-3.862c0-.074-.06-.149-.149-.149m.958.074c-.089 0-.149.06-.149.134l-.119 3.788.119 3.801c0 .074.06.149.149.149.089 0 .149-.074.149-.149l.134-3.801-.134-3.788c0-.074-.06-.134-.149-.134m.973-.089c-.09 0-.164.074-.164.149l-.105 3.876.105 3.787c0 .074.074.149.164.149.09 0 .15-.074.15-.149l.119-3.787-.119-3.876c0-.074-.06-.149-.15-.149m.958.134c-.089 0-.149.074-.149.149l-.089 3.757.089 3.802c0 .074.06.134.149.134.09 0 .15-.06.15-.134l.119-3.802-.119-3.757c0-.074-.06-.149-.15-.149m.972-.165c-.089 0-.149.075-.149.15l-.089 3.922.089 3.802c0 .074.06.149.149.149.09 0 .15-.074.15-.149l.104-3.802-.104-3.922c0-.074-.06-.15-.15-.15m.972.165c-.089 0-.149.074-.149.149l-.074 3.757.074 3.802c0 .074.06.134.149.134.09 0 .149-.06.149-.134l.09-3.802-.09-3.757c0-.074-.06-.149-.149-.149m.958-.119c-.089 0-.149.06-.149.134l-.074 3.876.074 3.802c0 .074.06.134.149.134.089 0 .149-.06.149-.134l.104-3.802-.104-3.876c0-.074-.06-.134-.149-.134m.973.119c-.09 0-.15.06-.15.134l-.074 3.757.074 3.802c0 .074.06.134.15.134.089 0 .149-.06.149-.134l.089-3.802-.089-3.757c0-.074-.06-.134-.149-.134M18 11.53c-.089 0-.164.074-.164.149l-.06 3.787.06 3.801c0 .075.074.15.164.15.09 0 .164-.075.164-.15l.075-3.801-.075-3.787c0-.075-.074-.149-.164-.149m.972.224c-.089 0-.164.06-.164.135l-.06 3.563.06 3.801c0 .074.074.134.164.134.09 0 .164-.06.164-.134l.074-3.801-.074-3.563c0-.074-.074-.135-.164-.135m.973-.165c-.09 0-.164.075-.164.15l-.06 3.727.06 3.802c0 .074.074.149.164.149.09 0 .165-.074.165-.149l.074-3.802-.074-3.727c0-.074-.074-.15-.165-.15m.972.194c-.089 0-.164.06-.164.135l-.045 3.533.045 3.801c0 .075.075.135.164.135.09 0 .165-.06.165-.135l.074-3.801-.074-3.533c0-.075-.074-.135-.165-.135m.973-.194c-.09 0-.165.075-.165.15l-.045 3.727.045 3.802c0 .074.074.149.165.149.089 0 .164-.074.164-.149l.06-3.802-.06-3.727c0-.074-.074-.15-.164-.15m.972.224c-.09 0-.164.06-.164.135l-.045 3.533.045 3.801c0 .074.074.134.164.134.09 0 .165-.06.165-.134l.074-3.801-.074-3.533c0-.075-.074-.135-.165-.135m.973-.194c-.09 0-.164.074-.164.149l-.045 3.727.045 3.802c0 .074.074.149.164.149.09 0 .164-.074.164-.149l.06-3.802-.06-3.727c0-.074-.074-.149-.164-.149"/></svg>',
    'tumblr': '<svg class="w-5 h-5" fill="currentColor" viewBox="0 0 24 24"><path d="M14.563 24c-5.093 0-7.031-3.756-7.031-6.411V9.747H5.116V6.648c3.63-1.313 4.512-4.596 4.71-6.469C9.84.051 9.941 0 9.999 0h3.517v6.114h4.801v3.633h-4.82v7.47c.016 1.001.375 2.371 2.207 2.371h.09c.631-.02 1.486-.205 1.936-.419l1.156 3.425c-.436.636-2.4 1.374-4.156 1.404h-.178l.011.002z"/></svg>'
  };
  return iconMap[platform.toLowerCase()] || '';
}

// Get selected platforms
function getSelectedPlatforms() {
  const selectedPlatforms = [];
  const selects = document.querySelectorAll('.social-profile-item select');
  selects.forEach(select => {
    if (select.value) {
      selectedPlatforms.push(select.value);
    }
  });
  return selectedPlatforms;
}

// Update all platform selects to hide selected options
function updateAllPlatformSelects() {
  const selectedPlatforms = getSelectedPlatforms();
  const selects = document.querySelectorAll('.social-profile-item select');

  selects.forEach(select => {
    const currentValue = select.value;
    select.innerHTML = '<option value="">Chọn nền tảng</option>';

    socialPlatforms.forEach(p => {
      // Show option if it's not selected in other dropdowns, or if it's the current value
      if (!selectedPlatforms.includes(p.value) || p.value === currentValue) {
        const option = document.createElement('option');
        option.value = p.value;
        option.textContent = p.label;
        if (p.value === currentValue) {
          option.selected = true;
        }
        select.appendChild(option);
      }
    });
  });
}

// Add social profile
function addSocialProfile() {
  socialProfileCounter++;
  const container = document.getElementById('social-profiles-container');
  const newProfile = document.createElement('div');
  newProfile.className = 'flex items-center gap-2 social-profile-item';
  newProfile.setAttribute('data-id', socialProfileCounter);

  newProfile.innerHTML = `
    <select class="select select-bordered w-48 social-profile-platform" onchange="handlePlatformChange(${socialProfileCounter}, this.value); generateSchema()">
      <option value="">Chọn nền tảng</option>
      <option value="Facebook">Facebook</option>
      <option value="Twitter">Twitter</option>
      <option value="Instagram">Instagram</option>
      <option value="LinkedIn">LinkedIn</option>
      <option value="YouTube">YouTube</option>
      <option value="Pinterest">Pinterest</option>
      <option value="SoundCloud">SoundCloud</option>
      <option value="Tumblr">Tumblr</option>
      <option value="Wikipedia">Wikipedia</option>
      <option value="Other">Khác</option>
    </select>
    <input
      type="url"
      placeholder="URL"
      class="input input-bordered flex-1 social-profile-url"
      oninput="generateSchema()"
    />
    <button
      type="button"
      onclick="removeSocialProfile(${socialProfileCounter})"
      class="btn btn-ghost btn-sm btn-square text-error"
    >
      <svg
        xmlns="http://www.w3.org/2000/svg"
        fill="none"
        viewBox="0 0 24 24"
        stroke-width="1.5"
        stroke="currentColor"
        class="w-5 h-5"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          d="m14.74 9-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 0 1-2.244 2.077H8.084a2.25 2.25 0 0 1-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 0 0-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 0 1 3.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 0 0-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 0 0-7.5 0"
        />
      </svg>
    </button>
  `;

  container.appendChild(newProfile);
  updateAllPlatformSelects();
}

// Handle platform change
function handlePlatformChange(profileId, platform) {
  updateAllPlatformSelects();
}

// Remove social profile
function removeSocialProfile(id) {
  const container = document.getElementById('social-profiles-container');
  const itemToRemove = container.querySelector(`[data-id="${id}"]`);
  if (itemToRemove) {
    itemToRemove.remove();
    updateAllPlatformSelects();
  }
}

// Counter for video thumbnails
let videoThumbnailCounter = 1;

// Add new video thumbnail
function addVideoThumbnail() {
  videoThumbnailCounter++;
  const container = document.getElementById('video-thumbnails-container');
  const newRow = document.createElement('div');
  newRow.className = 'flex items-end gap-3 video-thumbnail-row';
  newRow.setAttribute('data-id', videoThumbnailCounter);

  newRow.innerHTML = `
    <div class="form-control flex-1">
      <input
        type="url"
        placeholder="URL"
        class="input input-bordered w-full video-thumbnail-url"
        oninput="generateSchema()"
      />
    </div>
    <button
      type="button"
      onclick="removeVideoThumbnail(${videoThumbnailCounter})"
      class="btn btn-ghost text-error"
    >
      <svg
        xmlns="http://www.w3.org/2000/svg"
        fill="none"
        viewBox="0 0 24 24"
        stroke-width="1.5"
        stroke="currentColor"
        class="w-5 h-5"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          d="m14.74 9-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 0 1-2.244 2.077H8.084a2.25 2.25 0 0 1-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 0 0-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 0 1 3.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 0 0-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 0 0-7.5 0"
        />
      </svg>
    </button>
  `;

  container.appendChild(newRow);
}

// Remove video thumbnail
function removeVideoThumbnail(id) {
  const container = document.getElementById('video-thumbnails-container');
  const rows = container.querySelectorAll('.video-thumbnail-row');

  // Don't allow removing if only one row remains
  if (rows.length > 1) {
    const rowToRemove = container.querySelector(`[data-id="${id}"]`);
    if (rowToRemove) {
      rowToRemove.remove();
    }
  }
}

// Counter for recipe thumbnails
let recipeThumbnailCounter = 1;

// Add new recipe thumbnail
function addRecipeThumbnail() {
  recipeThumbnailCounter++;
  const container = document.getElementById('recipe-thumbnails-container');
  const newRow = document.createElement('div');
  newRow.className = 'flex items-end gap-3 recipe-thumbnail-row';
  newRow.setAttribute('data-id', recipeThumbnailCounter);

  newRow.innerHTML = `
    <div class="form-control flex-1">
      <input
        type="url"
        placeholder="URL"
        class="input input-bordered w-full"
      />
    </div>
    <button
      type="button"
      onclick="removeRecipeThumbnail(${recipeThumbnailCounter})"
      class="btn btn-ghost text-error"
    >
      <svg
        xmlns="http://www.w3.org/2000/svg"
        fill="none"
        viewBox="0 0 24 24"
        stroke-width="1.5"
        stroke="currentColor"
        class="w-5 h-5"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          d="m14.74 9-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 0 1-2.244 2.077H8.084a2.25 2.25 0 0 1-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 0 0-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 0 1 3.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 0 0-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 0 0-7.5 0"
        />
      </svg>
    </button>
  `;

  container.appendChild(newRow);
}

// Remove recipe thumbnail
function removeRecipeThumbnail(id) {
  const container = document.getElementById('recipe-thumbnails-container');
  const rows = container.querySelectorAll('.recipe-thumbnail-row');

  // Don't allow removing if only one row remains
  if (rows.length > 1) {
    const rowToRemove = container.querySelector(`[data-id="${id}"]`);
    if (rowToRemove) {
      rowToRemove.remove();
    }
  }
}

// Counter for recipe ingredients
let recipeIngredientCounter = 1;

// Add new recipe ingredient
function addRecipeIngredient() {
  recipeIngredientCounter++;
  const container = document.getElementById('recipe-ingredients-container');
  const newIngredient = document.createElement('div');
  newIngredient.className = 'recipe-ingredient-item';
  newIngredient.setAttribute('data-id', recipeIngredientCounter);

  newIngredient.innerHTML = `
    <label class="label">
      <span class="label-text font-medium">Ingredient #${recipeIngredientCounter}</span>
    </label>
    <div class="flex items-end gap-3">
      <div class="form-control flex-1">
        <input
          type="text"
          placeholder="thành phần"
          class="input input-bordered w-full"
        />
      </div>
      <button
        type="button"
        onclick="removeRecipeIngredient(${recipeIngredientCounter})"
        class="btn btn-ghost text-error"
      >
      <svg
        xmlns="http://www.w3.org/2000/svg"
        fill="none"
        viewBox="0 0 24 24"
        stroke-width="1.5"
        stroke="currentColor"
        class="w-5 h-5"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          d="m14.74 9-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 0 1-2.244 2.077H8.084a2.25 2.25 0 0 1-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 0 0-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 0 1 3.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 0 0-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 0 0-7.5 0"
        />
      </svg>
    </button>
    </div>
  `;

  container.appendChild(newIngredient);
}

// Remove recipe ingredient
function removeRecipeIngredient(id) {
  const container = document.getElementById('recipe-ingredients-container');
  const itemToRemove = container.querySelector(`[data-id="${id}"]`);
  if (itemToRemove) {
    itemToRemove.remove();
  }
}

// Counter for recipe steps
let recipeStepCounter = 1;

// Add new recipe step
function addRecipeStep() {
  recipeStepCounter++;
  const container = document.getElementById('recipe-steps-container');
  const newStep = document.createElement('div');
  newStep.className = 'border border-base-300 rounded-lg p-4 relative recipe-step-item';
  newStep.setAttribute('data-id', recipeStepCounter);

  newStep.innerHTML = `
    <button
      type="button"
      onclick="removeRecipeStep(${recipeStepCounter})"
      class="btn btn-ghost btn-sm btn-square absolute top-2 right-2 text-error"
    >
      <svg
        xmlns="http://www.w3.org/2000/svg"
        fill="none"
        viewBox="0 0 24 24"
        stroke-width="1.5"
        stroke="currentColor"
        class="w-5 h-5"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          d="m14.74 9-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 0 1-2.244 2.077H8.084a2.25 2.25 0 0 1-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 0 0-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 0 1 3.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 0 0-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 0 0-7.5 0"
        />
      </svg>
    </button>
    <h4 class="font-medium mb-3">Step #${recipeStepCounter}</h4>
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
      <div class="form-control lg:col-span-2">
        <label class="label">
          <span class="label-text">Step #${recipeStepCounter}</span>
        </label>
        <textarea
          placeholder="bước ${recipeStepCounter}"
          class="textarea textarea-bordered w-full"
          rows="2"
        ></textarea>
      </div>
      <div class="form-control">
        <label class="label">
          <span class="label-text">Name</span>
        </label>
        <input type="text" placeholder="Tên..." class="input input-bordered w-full" />
      </div>
      <div class="form-control">
        <label class="label">
          <span class="label-text">URL</span>
        </label>
        <input type="url" placeholder="URL" class="input input-bordered w-full" />
      </div>
      <div class="form-control lg:col-span-2">
        <label class="label">
          <span class="label-text">Image</span>
        </label>
        <input type="url" placeholder="URL" class="input input-bordered w-full" />
      </div>
    </div>
  `;

  container.appendChild(newStep);
}

// Remove recipe step
function removeRecipeStep(id) {
  const container = document.getElementById('recipe-steps-container');
  const steps = container.querySelectorAll('.recipe-step-item');

  // Don't allow removing if only one step remains
  if (steps.length > 1) {
    const itemToRemove = container.querySelector(`[data-id="${id}"]`);
    if (itemToRemove) {
      itemToRemove.remove();
    }
  }
}

// Counter for recipe reviews
let recipeReviewCounter = 1;

// Add new recipe review
function addRecipeReview() {
  recipeReviewCounter++;
  const container = document.getElementById('recipe-reviews-container');
  const newReview = document.createElement('div');
  newReview.className = 'border border-base-300 rounded-lg p-4 relative recipe-review-item';
  newReview.setAttribute('data-id', recipeReviewCounter);

  newReview.innerHTML = `
    <button
      type="button"
      onclick="removeRecipeReview(${recipeReviewCounter})"
      class="btn btn-ghost btn-sm btn-square absolute top-2 right-2 text-error"
    >
      <svg
        xmlns="http://www.w3.org/2000/svg"
        fill="none"
        viewBox="0 0 24 24"
        stroke-width="1.5"
        stroke="currentColor"
        class="w-5 h-5"
      >
        <path
          stroke-linecap="round"
          stroke-linejoin="round"
          d="m14.74 9-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 0 1-2.244 2.077H8.084a2.25 2.25 0 0 1-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 0 0-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 0 1 3.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 0 0-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 0 0-7.5 0"
        />
      </svg>
    </button>
    <h4 class="font-medium mb-3">#${recipeReviewCounter} Review's name</h4>
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
      <div class="form-control">
        <label class="label">
          <span class="label-text">#${recipeReviewCounter} Review's name</span>
        </label>
        <input type="text" placeholder="bước ${recipeReviewCounter}" class="input input-bordered w-full" />
      </div>
      <div class="form-control lg:row-span-2">
        <label class="label">
          <span class="label-text">Review's body</span>
        </label>
        <textarea
          placeholder="..."
          class="textarea textarea-bordered w-full"
          rows="4"
        ></textarea>
      </div>
      <div class="form-control">
        <label class="label">
          <span class="label-text">Rating</span>
        </label>
        <input type="text" placeholder="..." class="input input-bordered w-full" />
      </div>
      <div class="form-control">
        <label class="label">
          <span class="label-text">Date</span>
        </label>
        <input type="date" placeholder="Date posted" class="input input-bordered w-full" />
      </div>
      <div class="form-control lg:col-span-2">
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
          <div class="form-control">
            <label class="label">
              <span class="label-text">Author</span>
            </label>
            <input type="text" placeholder="..." class="input input-bordered w-full" />
          </div>
          <div class="form-control">
            <label class="label">
              <span class="label-text">Publisher</span>
            </label>
            <input type="text" placeholder="..." class="input input-bordered w-full" />
          </div>
        </div>
      </div>
    </div>
  `;

  container.appendChild(newReview);
}

// Remove recipe review
function removeRecipeReview(id) {
  const container = document.getElementById('recipe-reviews-container');
  const reviews = container.querySelectorAll('.recipe-review-item');

  // Don't allow removing if only one review remains
  if (reviews.length > 1) {
    const itemToRemove = container.querySelector(`[data-id="${id}"]`);
    if (itemToRemove) {
      itemToRemove.remove();
    }
  }
}

// Generate schema based on current form type
function generateSchema() {
  const schemaType = document.getElementById('schema-type-select')?.value;

  if (schemaType === 'Article') {
    generateArticleSchema();
  } else if (schemaType === 'Breadcrumb') {
    generateBreadcrumbSchema();
  } else if (schemaType === 'Event') {
    generateEventSchema();
  } else if (schemaType === 'FAQ') {
    generateFAQSchema();
  } else if (schemaType === 'HowTo') {
    generateHowToSchema();
  } else if (schemaType === 'JobPosting') {
    generateJobPostingSchema();
  } else if (schemaType === 'LocalBusiness') {
    generateLocalBusinessSchema();
  } else if (schemaType === 'Person') {
    generatePersonSchema();
  } else if (schemaType === 'Video') {
    generateVideoSchema();
  } else if (schemaType === 'Website') {
    generateWebsiteSchema();
  } else if (schemaType === 'Recipe') {
    generateRecipeSchema();
  }
  // Add other schema types here in the future
}

// Generate HowTo schema
function generateHowToSchema() {
  const name = document.getElementById('howto-name')?.value?.trim() || "";
  const totalTime = document.getElementById('howto-total-time')?.value?.trim() || "";
  const cost = document.getElementById('howto-cost')?.value?.trim() || "";
  const currency = document.getElementById('howto-currency')?.value?.trim() || "";
  const description = document.getElementById('howto-description')?.value?.trim() || "";

  // Get supplies
  const supplyItems = document.querySelectorAll('.supply-item');
  const supplies = [];
  supplyItems.forEach(item => {
    const supplyName = item.querySelector('.supply-name')?.value?.trim() || "";
    if (supplyName) {
      supplies.push({
        "@type": "HowToSupply",
        "name": supplyName
      });
    }
  });

  // Get tools
  const toolItems = document.querySelectorAll('.tool-item');
  const tools = [];
  toolItems.forEach(item => {
    const toolName = item.querySelector('.tool-name')?.value?.trim() || "";
    if (toolName) {
      tools.push({
        "@type": "HowToTool",
        "name": toolName
      });
    }
  });

  // Get steps
  const stepItems = document.querySelectorAll('.step-item');
  const steps = [];
  stepItems.forEach(item => {
    const instruction = item.querySelector('.step-instruction')?.value?.trim() || "";
    const image = item.querySelector('.step-image')?.value?.trim() || "";
    const stepName = item.querySelector('.step-name')?.value?.trim() || "";
    const url = item.querySelector('.step-url')?.value?.trim() || "";

    if (instruction || image || stepName || url) {
      const step = {
        "@type": "HowToStep",
        "text": instruction,
        "image": image,
        "name": stepName,
        "url": url
      };
      steps.push(step);
    }
  });

  const schema = {
    "@context": "https://schema.org/",
    "@type": "HowTo",
    "name": name,
    "description": description,
    "totalTime": totalTime ? `PT${totalTime}M` : "",
    "estimatedCost": (cost && currency) ? {
      "@type": "MonetaryAmount",
      "currency": currency,
      "value": cost
    } : undefined,
    "supply": supplies.length === 1 ? supplies[0] : (supplies.length > 0 ? supplies : undefined),
    "tool": tools.length === 1 ? tools[0] : (tools.length > 0 ? tools : undefined),
    "step": steps
  };

  updateSchemaPreview(schema);
}

// Generate FAQ schema
function generateFAQSchema() {
  const faqItems = document.querySelectorAll('.faq-item');
  const mainEntity = [];

  faqItems.forEach(item => {
    const question = item.querySelector('.faq-question')?.value?.trim() || "";
    const answer = item.querySelector('.faq-answer')?.value?.trim() || "";

    if (question || answer) {
      mainEntity.push({
        "@type": "Question",
        "name": question,
        "acceptedAnswer": {
          "@type": "Answer",
          "text": answer
        }
      });
    }
  });

  const schema = {
    "@context": "https://schema.org",
    "@type": "FAQPage",
    "mainEntity": mainEntity.length === 1 ? mainEntity[0] : mainEntity
  };

  updateSchemaPreview(schema);
}

// Generate Event schema
function generateEventSchema() {
  const name = document.getElementById('event-name')?.value?.trim() || "";
  const image = document.getElementById('event-image')?.value?.trim() || "";
  const description = document.getElementById('event-description')?.value?.trim() || "";
  
  const startDate = document.getElementById('event-start-date')?.value || "";
  const startTime = document.getElementById('event-start-time')?.value || "";
  const startDateTime = (startDate && startTime) ? `${startDate}T${startTime}` : startDate;

  const endDate = document.getElementById('event-end-date')?.value || "";
  const endTime = document.getElementById('event-end-time')?.value || "";
  const endDateTime = (endDate && endTime) ? `${endDate}T${endTime}` : endDate;

  const eventStatus = document.getElementById('event-status')?.value || "";
  const eventAttendanceMode = document.getElementById('event-attendance-mode')?.value || "";
  
  const performerType = document.getElementById('event-performer-type')?.value || "";
  const performerName = document.getElementById('event-performer-name')?.value?.trim() || "";
  
  const currency = document.getElementById('event-currency')?.value || "";

  // Get tickets (offers)
  const ticketItems = document.querySelectorAll('.ticket-item');
  const offers = [];

  ticketItems.forEach(item => {
    const ticketName = item.querySelector('.ticket-name')?.value?.trim() || "";
    const ticketPrice = item.querySelector('.ticket-price')?.value?.trim() || "";
    const ticketValidFrom = item.querySelector('.ticket-valid-from')?.value || "";
    const ticketUrl = item.querySelector('.ticket-url')?.value?.trim() || "";
    const ticketAvailability = item.querySelector('.ticket-availability')?.value || "";

    if (ticketName || ticketPrice || ticketUrl) {
      const offer = {
        "@type": "Offer",
        "name": ticketName,
        "price": ticketPrice,
        "priceCurrency": currency,
        "validFrom": ticketValidFrom,
        "url": ticketUrl,
        "availability": ticketAvailability ? `https://schema.org/${ticketAvailability}` : ""
      };
      offers.push(offer);
    }
  });

  const schema = {
    "@context": "https://schema.org",
    "@type": "Event",
    "name": name,
    "startDate": startDateTime,
    "eventStatus": eventStatus ? `https://schema.org/${eventStatus}` : "",
    "offers": offers.length === 1 ? offers[0] : (offers.length > 0 ? offers : undefined),
    "image": image,
    "description": description,
    "endDate": endDateTime,
    "eventAttendanceMode": eventAttendanceMode ? `https://schema.org/${eventAttendanceMode}` : ""
  };

  if (performerType && performerName) {
    schema.performer = {
      "@type": performerType,
      "name": performerName
    };
  }

  updateSchemaPreview(schema);
}

// Generate Article schema
function generateArticleSchema() {
  // Get all values
  const articleType = document.getElementById('article-type')?.value || "Article";
  const headline = document.getElementById('article-headline')?.value?.trim() || "";
  
  // Get image URLs
  const imageInputs = document.querySelectorAll('.article-image-url');
  const images = Array.from(imageInputs).map(input => input.value?.trim() || "");
  
  // Determine if image should be string or array (only 1 image = string, 2+ = array)
  const imageValue = images.length === 1 ? images[0] : images;
  
  // Get author info
  const authorType = document.getElementById('article-author-type')?.value || "";
  const authorName = document.getElementById('article-author-name')?.value?.trim() || "";
  
  // Get publisher info
  const publisherName = document.getElementById('article-publisher-name')?.value?.trim() || "";
  const publisherLogo = document.getElementById('article-publisher-logo')?.value?.trim() || "";
  
  // Get date
  const datePublished = document.getElementById('article-date-published')?.value || "";

  // Build schema with all fields, keeping empty strings
  const schema = {
    "@context": "https://schema.org",
    "@type": articleType,
    "headline": headline,
    "image": imageValue,
    "author": {
      "@type": authorType,
      "name": authorName
    },
    "publisher": {
      "@type": "Organization",
      "name": publisherName,
      "logo": {
        "@type": "ImageObject",
        "url": publisherLogo
      }
    },
    "datePublished": datePublished
  };

  // Update preview
  updateSchemaPreview(schema);
}

// Generate Breadcrumb schema
function generateBreadcrumbSchema() {
  // Get all breadcrumb items
  const breadcrumbItems = document.querySelectorAll('.breadcrumb-item');
  const itemListElement = [];

  breadcrumbItems.forEach((item, index) => {
    const nameInput = item.querySelector('.breadcrumb-name');
    const urlInput = item.querySelector('.breadcrumb-url');
    
    const name = nameInput?.value?.trim() || "";
    const url = urlInput?.value?.trim() || "";

    itemListElement.push({
      "@type": "ListItem",
      "position": index + 1,
      "name": name,
      "item": url
    });
  });

  // Build schema
  const schema = {
    "@context": "https://schema.org/",
    "@type": "BreadcrumbList",
    "itemListElement": itemListElement
  };

  // Update preview
  updateSchemaPreview(schema);
}

// Update schema preview display
function updateSchemaPreview(schema) {
  const schemaPreview = document.getElementById('schema-preview');
  const formattedJson = JSON.stringify(schema, null, 4);
  const wrappedSchema = `<script type="application/ld+json">\n${formattedJson}\n<\/script>`;
  schemaPreview.textContent = wrappedSchema;

  // Remove hljs class and data-highlighted attribute to ensure re-highlighting
  schemaPreview.classList.remove('hljs');
  schemaPreview.removeAttribute('data-highlighted');

  // Re-apply syntax highlighting
  if (typeof hljs !== 'undefined') {
    hljs.highlightElement(schemaPreview);
    // Fix background to match outer container
    schemaPreview.style.backgroundColor = 'transparent';
    schemaPreview.style.padding = '0';
  }
}

// Copy schema to clipboard
function copySchemaToClipboard() {
  const schemaCode = document.getElementById('schema-preview');
  const textToCopy = schemaCode.textContent;

  navigator.clipboard.writeText(textToCopy).then(function() {
    // Show success feedback
    const copyBtn = event.target.closest('button');
    const originalText = copyBtn.innerHTML;

    copyBtn.innerHTML = '<span class="text-sm">Copied!</span>';

    setTimeout(function() {
      copyBtn.innerHTML = originalText;
    }, 2000);
  }).catch(function(err) {
    console.error('Failed to copy:', err);
  });
}

// Make functions globally available
window.toggleSchemaForm = toggleSchemaForm;
window.addImageUrl = addImageUrl;
window.removeImageUrl = removeImageUrl;
window.addBreadcrumbItem = addBreadcrumbItem;
window.removeBreadcrumbItem = removeBreadcrumbItem;
window.addTicket = addTicket;
window.removeTicket = removeTicket;
window.addFaqItem = addFaqItem;
// Generate JobPosting schema
function generateJobPostingSchema() {
  const title = document.getElementById('job-title')?.value?.trim() || "";
  const identifier = document.getElementById('job-identifier')?.value?.trim() || "";
  const description = document.getElementById('job-description')?.value?.trim() || "";
  const company = document.getElementById('job-company')?.value?.trim() || "";
  const companyUrl = document.getElementById('job-company-url')?.value?.trim() || "";
  const companyLogo = document.getElementById('job-company-logo')?.value?.trim() || "";
  const industry = document.getElementById('job-industry')?.value?.trim() || "";
  const employmentType = document.getElementById('job-employment-type')?.value || "";
  const workHours = document.getElementById('job-work-hours')?.value?.trim() || "";
  const datePosted = document.getElementById('job-date-posted')?.value || "";
  const validThrough = document.getElementById('job-expire-date')?.value || "";
  const isRemote = document.getElementById('job-remote')?.checked || false;
  const country = document.getElementById('job-country')?.value || "";
  const region = document.getElementById('job-region')?.value || "";
  const street = document.getElementById('job-street')?.value?.trim() || "";
  const city = document.getElementById('job-city')?.value?.trim() || "";
  const zip = document.getElementById('job-zip')?.value?.trim() || "";
  const salaryMin = document.getElementById('job-salary-min')?.value?.trim() || "";
  const salaryMax = document.getElementById('job-salary-max')?.value?.trim() || "";
  const currency = document.getElementById('job-currency')?.value || "";
  const salaryPeriod = document.getElementById('job-salary-period')?.value || "";

  const schema = {
    "@context": "https://schema.org/",
    "@type": "JobPosting",
    "title": title,
    "description": description,
    "hiringOrganization": {
      "@type": "Organization",
      "name": company
    },
    "employmentType": employmentType,
    "datePosted": datePosted,
    "validThrough": validThrough,
  };

  if (identifier) {
    schema.identifier = {
      "@type": "PropertyValue",
      "name": company,
      "value": identifier
    };
  }

  if (companyUrl) {
    schema.hiringOrganization.sameAs = companyUrl;
  }
  
  if (companyLogo) {
    schema.hiringOrganization.logo = companyLogo;
  }

  if (industry) {
    schema.industry = industry;
  }

  if (workHours) {
    schema.workHours = workHours;
  }

  if (isRemote) {
    schema.jobLocationType = "TELECOMMUTE";
    schema.applicantLocationRequirements = {
      "@type": "Country",
      "name": country || "VN"
    };
  } else {
    schema.jobLocation = {
      "@type": "Place",
      "address": {
        "@type": "PostalAddress",
        "streetAddress": street,
        "addressLocality": city,
        "addressRegion": region,
        "postalCode": zip,
        "addressCountry": country
      }
    };
  }

  if (salaryMin || salaryMax) {
    schema.baseSalary = {
      "@type": "MonetaryAmount",
      "currency": currency,
      "value": {
        "@type": "QuantitativeValue",
        "unitText": salaryPeriod
      }
    };

    if (salaryMin) schema.baseSalary.value.minValue = salaryMin;
    if (salaryMax) schema.baseSalary.value.maxValue = salaryMax;
    
    if (salaryMin && !salaryMax) {
        schema.baseSalary.value.value = salaryMin;
        delete schema.baseSalary.value.minValue;
    }
  }

  updateSchemaPreview(schema);
}

// Generate LocalBusiness schema
function generateLocalBusinessSchema() {
  const type = document.getElementById('localbusiness-type')?.value || "LocalBusiness";
  const name = document.getElementById('localbusiness-name')?.value?.trim() || "";
  const image = document.getElementById('localbusiness-image')?.value?.trim() || "";
  const id = document.getElementById('localbusiness-id')?.value?.trim() || "";
  const url = document.getElementById('localbusiness-url')?.value?.trim() || "";
  const phone = document.getElementById('localbusiness-phone')?.value?.trim() || "";
  const priceRange = document.getElementById('localbusiness-price')?.value?.trim() || "";
  const street = document.getElementById('localbusiness-street')?.value?.trim() || "";
  const city = document.getElementById('localbusiness-city')?.value?.trim() || "";
  const zip = document.getElementById('localbusiness-zip')?.value?.trim() || "";
  const country = document.getElementById('localbusiness-country')?.value || "";
  const region = document.getElementById('localbusiness-region')?.value || "";
  const lat = document.getElementById('localbusiness-lat')?.value?.trim() || "";
  const lng = document.getElementById('localbusiness-lng')?.value?.trim() || "";
  const open247 = document.getElementById('localbusiness-247')?.checked || false;
  const socials = document.getElementById('localbusiness-socials')?.value?.trim() || "";

  const schema = {
    "@context": "https://schema.org",
    "@type": type,
    "name": name,
    "image": image,
    "@id": id,
    "url": url,
    "telephone": phone,
    "address": {
      "@type": "PostalAddress",
      "streetAddress": street,
      "addressLocality": city,
      "postalCode": zip,
      "addressCountry": country,
      "addressRegion": region
    }
  };

  if (priceRange) {
    schema.priceRange = priceRange;
  }

  if (lat && lng) {
    schema.geo = {
      "@type": "GeoCoordinates",
      "latitude": lat,
      "longitude": lng
    };
  }

  if (socials) {
    // Split by comma if multiple
    const socialList = socials.split(',').map(s => s.trim()).filter(s => s);
    if (socialList.length > 0) {
      schema.sameAs = socialList.length === 1 ? socialList[0] : socialList;
    }
  }

  // Opening Hours
  if (open247) {
    schema.openingHoursSpecification = {
      "@type": "OpeningHoursSpecification",
      "dayOfWeek": [
        "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"
      ],
      "opens": "00:00",
      "closes": "23:59"
    };
  } else {
    const openingHours = [];
    const openingHourItems = document.querySelectorAll('.main-opening-hour-item');
    openingHourItems.forEach(item => {
      const day = item.querySelector('.main-opening-day')?.value || "";
      const opens = item.querySelector('.main-opening-opens')?.value || "";
      const closes = item.querySelector('.main-opening-closes')?.value || "";
      
      if (day && opens && closes) {
        openingHours.push({
          "@type": "OpeningHoursSpecification",
          "dayOfWeek": day,
          "opens": opens,
          "closes": closes
        });
      }
    });

    if (openingHours.length > 0) {
      schema.openingHoursSpecification = openingHours.length === 1 ? openingHours[0] : openingHours;
    }
  }

  // Departments
  const departments = [];
  const departmentItems = document.querySelectorAll('.department-item');
  departmentItems.forEach(item => {
    const deptType = item.querySelector('.department-type')?.value || "LocalBusiness";
    const deptName = item.querySelector('.department-name')?.value?.trim() || "";
    const deptImage = item.querySelector('.department-image')?.value?.trim() || "";
    const deptPhone = item.querySelector('.department-phone')?.value?.trim() || "";
    const deptId = item.getAttribute('data-id');

    const deptSchema = {
      "@type": deptType,
      "name": deptName,
      "image": deptImage,
      "telephone": deptPhone
    };

    // Department Opening Hours
    const deptOpeningHours = [];
    const deptOpeningHourItems = item.querySelectorAll('.dept-opening-hour-item');
    deptOpeningHourItems.forEach(hourItem => {
      const day = hourItem.querySelector('.dept-opening-day')?.value || "";
      const opens = hourItem.querySelector('.dept-opening-opens')?.value || "";
      const closes = hourItem.querySelector('.dept-opening-closes')?.value || "";

      if (day && opens && closes) {
        deptOpeningHours.push({
          "@type": "OpeningHoursSpecification",
          "dayOfWeek": day,
          "opens": opens,
          "closes": closes
        });
      }
    });

    if (deptOpeningHours.length > 0) {
      deptSchema.openingHoursSpecification = deptOpeningHours.length === 1 ? deptOpeningHours[0] : deptOpeningHours;
    }

    if (deptName) { // Only add if name is present
        departments.push(deptSchema);
    }
  });

  if (departments.length > 0) {
    schema.department = departments.length === 1 ? departments[0] : departments;
  }

  updateSchemaPreview(schema);
}

// Generate Person schema
function generatePersonSchema() {
  const name = document.getElementById('person-name')?.value?.trim() || "";
  const url = document.getElementById('person-url')?.value?.trim() || "";
  const image = document.getElementById('person-image')?.value?.trim() || "";
  const jobTitle = document.getElementById('person-job-title')?.value?.trim() || "";
  const company = document.getElementById('person-company')?.value?.trim() || "";

  const schema = {
    "@context": "https://schema.org/",
    "@type": "Person",
    "name": name,
    "url": url,
    "image": image
  };

  if (jobTitle) {
    schema.jobTitle = jobTitle;
  }

  if (company) {
    schema.worksFor = {
      "@type": "Organization",
      "name": company
    };
  }

  // Social Profiles (sameAs)
  const socialProfiles = [];
  const socialProfileItems = document.querySelectorAll('.social-profile-item');
  socialProfileItems.forEach(item => {
    const profileUrl = item.querySelector('.social-profile-url')?.value?.trim() || "";
    if (profileUrl) {
      socialProfiles.push(profileUrl);
    }
  });

  if (socialProfiles.length > 0) {
    schema.sameAs = socialProfiles.length === 1 ? socialProfiles[0] : socialProfiles;
  } else {
    // If user wants to see the field even if empty (based on request example having empty strings)
    // But usually we don't include empty fields. 
    // However, the user request showed: "sameAs": ["", "", "", ""] which implies they might want the structure.
    // But standard practice is to omit empty. 
    // The user said: "nếu chỉ có 1 thì sẽ chỉ là sameAs: "" thôi nhé"
    // This implies if there is 1 item, it's a string. If multiple, it's an array.
    // I will stick to adding only if values exist.
  }

  updateSchemaPreview(schema);
}

// Generate Video schema
function generateVideoSchema() {
  const name = document.getElementById('video-name')?.value?.trim() || "";
  const description = document.getElementById('video-description')?.value?.trim() || "";
  const uploadDate = document.getElementById('video-upload-date')?.value || "";
  const minutes = document.getElementById('video-minutes')?.value || "0";
  const seconds = document.getElementById('video-seconds')?.value || "0";

  const schema = {
    "@context": "https://schema.org",
    "@type": "VideoObject",
    "name": name,
    "description": description,
    "uploadDate": uploadDate,
    "duration": `PT${minutes}M${seconds}S`
  };

  // Thumbnail URLs
  const thumbnailUrls = [];
  const thumbnailItems = document.querySelectorAll('.video-thumbnail-url');
  thumbnailItems.forEach(item => {
    const url = item.value?.trim() || "";
    if (url) {
      thumbnailUrls.push(url);
    }
  });

  if (thumbnailUrls.length > 0) {
    schema.thumbnailUrl = thumbnailUrls.length === 1 ? thumbnailUrls[0] : thumbnailUrls;
  } else {
    schema.thumbnailUrl = ""; // As per request example, though usually omitted if empty
  }

  updateSchemaPreview(schema);
}

// Generate Website schema
function generateWebsiteSchema() {
  const name = document.getElementById('website-name')?.value?.trim() || "";
  const url = document.getElementById('website-url')?.value?.trim() || "";
  const searchUrl = document.getElementById('website-search-url')?.value?.trim() || "";
  const searchSuffix = document.getElementById('website-search-suffix')?.value?.trim() || "";

  const schema = {
    "@context": "https://schema.org/",
    "@type": "WebSite",
    "name": name,
    "url": url
  };

  if (searchUrl) {
    schema.potentialAction = {
      "@type": "SearchAction",
      "target": `${searchUrl}{search_term_string}${searchSuffix}`,
      "query-input": "required name=search_term_string"
    };
  }

  updateSchemaPreview(schema);
}

window.removeFaqItem = removeFaqItem;
window.addSupply = addSupply;
window.removeSupply = removeSupply;
window.addTool = addTool;
window.removeTool = removeTool;
window.addStep = addStep;
window.removeStep = removeStep;
window.addMainOpeningHour = addMainOpeningHour;
window.removeMainOpeningHour = removeMainOpeningHour;
window.addDepartment = addDepartment;
window.removeDepartment = removeDepartment;
window.addDepartmentOpeningHour = addDepartmentOpeningHour;
window.removeDepartmentOpeningHour = removeDepartmentOpeningHour;
window.addSocialProfile = addSocialProfile;
window.removeSocialProfile = removeSocialProfile;
window.handlePlatformChange = handlePlatformChange;
window.addVideoThumbnail = addVideoThumbnail;
window.removeVideoThumbnail = removeVideoThumbnail;
window.addRecipeThumbnail = addRecipeThumbnail;
window.removeRecipeThumbnail = removeRecipeThumbnail;
window.addRecipeIngredient = addRecipeIngredient;
window.removeRecipeIngredient = removeRecipeIngredient;
window.addRecipeStep = addRecipeStep;
window.removeRecipeStep = removeRecipeStep;
window.addRecipeReview = addRecipeReview;
window.removeRecipeReview = removeRecipeReview;
window.generateSchema = generateSchema;
window.copySchemaToClipboard = copySchemaToClipboard;

// Generate Recipe schema
function generateRecipeSchema() {
  const name = document.getElementById('recipe-name')?.value?.trim() || "";
  const description = document.getElementById('recipe-description')?.value?.trim() || "";
  const keywords = document.getElementById('recipe-keywords')?.value?.trim() || "";
  const creator = document.getElementById('recipe-creator')?.value?.trim() || "";
  const prepTimeVal = document.getElementById('recipe-prep-time')?.value?.trim();
  const cookTimeVal = document.getElementById('recipe-cook-time')?.value?.trim();
  const category = document.getElementById('recipe-category')?.value?.trim() || "appetizer";
  const calories = document.getElementById('recipe-nutrition-calories')?.value?.trim() || "";

  const prepTime = prepTimeVal ? `PT${prepTimeVal}M` : "";
  const cookTime = cookTimeVal ? `PT${cookTimeVal}M` : "";
  let totalTime = "";
  if (prepTimeVal && cookTimeVal) {
    totalTime = `PT${parseInt(prepTimeVal) + parseInt(cookTimeVal)}M`;
  }

  // Images
  const imageInputs = document.querySelectorAll('.recipe-thumbnail-url');
  let images = [];
  imageInputs.forEach(input => {
    if (input.value.trim()) {
      images.push(input.value.trim());
    }
  });

  // Ingredients
  const ingredientInputs = document.querySelectorAll('.recipe-ingredient-text');
  let ingredients = [];
  ingredientInputs.forEach(input => {
    if (input.value.trim()) {
      ingredients.push(input.value.trim());
    }
  });

  // Instructions
  const stepInputs = document.querySelectorAll('.recipe-step-text');
  let instructions = [];
  stepInputs.forEach(input => {
    if (input.value.trim()) {
      instructions.push({
        "@type": "HowToStep",
        "text": input.value.trim()
      });
    }
  });

  // Reviews
  let reviews = [];
  const reviewContainers = document.querySelectorAll('.recipe-review-item');
  reviewContainers.forEach(container => {
    const reviewName = container.querySelector('.recipe-review-name')?.value?.trim() || "";
    const reviewBody = container.querySelector('.recipe-review-body')?.value?.trim() || "";
    const reviewAuthor = container.querySelector('.recipe-review-author')?.value?.trim() || "";

    if (reviewName || reviewBody || reviewAuthor) {
      reviews.push({
        "@type": "Review",
        "name": reviewName,
        "reviewBody": reviewBody,
        "author": {
          "@type": "Person",
          "name": reviewAuthor
        }
      });
    }
  });

  const schema = {
    "@context": "https://schema.org/",
    "@type": "Recipe",
    "name": name,
    "image": images.length === 1 ? images[0] : (images.length > 0 ? images : ["", ""]),
    "description": description,
    "keywords": keywords,
    "author": {
      "@type": "Person",
      "name": creator
    },
    "prepTime": prepTime,
    "cookTime": cookTime,
    "totalTime": totalTime,
    "recipeCategory": category,
    "nutrition": {
      "@type": "NutritionInformation",
      "calories": calories
    },
    "recipeIngredient": ingredients.length === 1 ? ingredients[0] : (ingredients.length > 0 ? ingredients : ["", ""]),
    "recipeInstructions": instructions.length === 1 ? instructions[0] : (instructions.length > 0 ? instructions : [
      { "@type": "HowToStep", "text": "" },
      { "@type": "HowToStep", "text": "" }
    ]),
    "review": reviews.length === 1 ? reviews[0] : (reviews.length > 0 ? reviews : {
      "@type": "Review",
      "name": "ggg",
      "reviewBody": "",
      "author": {
        "@type": "Person",
        "name": ""
      }
    })
  };

  updateSchemaPreview(schema);
}
